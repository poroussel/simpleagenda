#import <AppKit/AppKit.h>
#import "Event.h"
#import "Task.h"
#import "AgendaStore.h"
#import "WebDAVResource.h"
#import "iCalTree.h"
#import "NSString+SimpleAgenda.h"
#import "InvocationOperation.h"
#import "StoreManager.h"
#import "defines.h"

@interface iCalStoreDialog : NSObject
{
  IBOutlet id panel;
  IBOutlet id name;
  IBOutlet id url;
  IBOutlet id ok;
  IBOutlet id error;
  IBOutlet id warning;
}
- (BOOL)show;
- (NSString *)url;
@end
@implementation iCalStoreDialog
- (id)initWithName:(NSString *)storeName
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"iCalendar" owner:self])
      return nil;
    [warning setHidden:YES];
    [name setStringValue:storeName];
    [url setStringValue:@"http://"];
  }
  return self;
}
- (void)dealloc
{
  [panel close];
  [super dealloc];
}
- (BOOL)show
{
  [ok setEnabled:NO];
  return [NSApp runModalForWindow:panel];
}
- (void)okClicked:(id)sender
{
  BOOL readable;
  WebDAVResource *resource;

  resource = AUTORELEASE([[WebDAVResource alloc] initWithURL:[NSURL URLWithString:[url stringValue]]]);
  readable = [resource readable];
  /* Read will fail if there's no resource yet, try to create an empty one */
  if (!readable && [resource httpStatus] != 401) {
    [resource writableWithData:[NSData data]];
    readable = [resource readable];
  }
  if (readable)
    [NSApp stopModalWithCode:1];
  else {
    [error setStringValue:[NSString stringWithFormat:@"Unable to read from this URL : %@", [[resource url] propertyForKey:NSHTTPPropertyStatusReasonKey]]];
    [warning setHidden:NO];
  }
}
- (void)cancelClicked:(id)sender
{
  [NSApp stopModalWithCode:0];
}
- (void)controlTextDidChange:(NSNotification *)notification
{
  NS_DURING
    {
      [ok setEnabled:[[url stringValue] isValidURL]];
    }
  NS_HANDLER
    {
      [ok setEnabled:NO];
    }
  NS_ENDHANDLER
}
- (NSString *)url
{
  return [url stringValue];
}
@end


@interface iCalStore : MemoryStore <SharedStore, ConfigListener>
{
  iCalTree *_tree;
  NSURL *_url;
  NSTimer *_refreshTimer;
  WebDAVResource *_resource;
}
- (void)initTimer;
- (void)doRead;
@end
@implementation iCalStore
- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjectsAndKeys:[[NSColor blueColor] description], ST_COLOR,
		       [[NSColor whiteColor] description], ST_TEXT_COLOR,
		       [NSNumber numberWithBool:NO], ST_RW,
		       [NSNumber numberWithBool:YES], ST_DISPLAY,
		       [NSNumber numberWithBool:NO], ST_REFRESH,
		       [NSNumber numberWithBool:YES], ST_ENABLED,
		       nil, nil];
}

- (id)initWithName:(NSString *)name
{
  self = [super initWithName:name];
  if (self) {
    _tree = [iCalTree new];
    _url = [[NSURL alloc] initWithString:[[self config] objectForKey:ST_URL]];
    _resource = [[WebDAVResource alloc] initWithURL:_url];
    [[self config] registerClient:self forKey:ST_REFRESH];
    [[self config] registerClient:self forKey:ST_REFRESH_INTERVAL];
    [[self config] registerClient:self forKey:ST_ENABLED];
    [self read];
    [self initTimer];
  }
  return self;
}

+ (BOOL)isUserInstanciable
{
  return YES;
}

+ (BOOL)registerWithName:(NSString *)name
{
  ConfigManager *cm;
  iCalStoreDialog *dialog;
  NSURL *storeURL;
  BOOL writable = NO;
  WebDAVResource *resource;

  dialog = [[iCalStoreDialog alloc] initWithName:name];
  if ([dialog show] == YES) {
    storeURL = [NSURL URLWithString:[dialog url]];
    resource = [[WebDAVResource alloc] initWithURL:storeURL];
    writable = NO;
    if ([resource get])
      writable = [resource writableWithData:[resource data]];
    [resource release];
    [dialog release];
    cm = [[ConfigManager alloc] initForKey:name];
    [cm setObject:[storeURL description] forKey:ST_URL];
    [cm setObject:[[self class] description] forKey:ST_CLASS];
    [cm setObject:[NSNumber numberWithBool:writable] forKey:ST_RW];
    [cm release];
    return YES;
  }
  [dialog release];
  return NO;
}

+ (NSString *)storeTypeName
{
  return @"iCalendar";
}

- (void)dealloc
{
  /* FIXME : this sould be handled by the super class */
  [[self config] unregisterClient:self];
  [_refreshTimer invalidate];
  [_refreshTimer release];
  [self write];
  DESTROY(_resource);
  DESTROY(_url);
  DESTROY(_tree);
  [super dealloc];
}

- (void)refreshData:(NSTimer *)timer
{
  [self read];
}

- (void)add:(Element *)elt
{
  if ([_tree add:elt]) {
    [super add:elt];
    [self write];
  }
}

- (void)remove:(Element *)elt
{
  if ([_tree remove:elt]) {
    [super remove:elt];
    [self write];
  }
}

- (void)update:(Element *)elt
{
  if ([_tree update:(Event *)elt]) {
    [super update:elt];
    [self write];
  }
}

- (void)read
{
  if ([self enabled])
    [[[StoreManager globalManager] operationQueue] addOperation:AUTORELEASE([[InvocationOperation alloc] initWithTarget:self selector:@selector(doRead) object:nil])];
}

- (BOOL)write
{
  NSData *data;

  if (![self modified] || ![self writable])
    return YES;
  data = [_tree iCalTreeAsData];
  if (data) {
    if ([_resource put:data attributes:nil]) {
      [_resource updateAttributes];
      [self setModified:NO];
      NSLog(@"iCalStore written to %@", [_url anonymousAbsoluteString]);
      return YES;
    }
    if ([_resource httpStatus] == 412) {
      NSRunAlertPanel(@"Error : data source modified", @"To prevent losing modifications, this agenda\nwill be updated and marked as read-only. ", @"Ok", nil, nil);
      [self read];
    }
    NSLog(@"Unable to write to %@, make this store read only", [_url anonymousAbsoluteString]);
    [self setWritable:NO];
    return NO;
  }
  return YES;
}

- (BOOL)periodicRefresh
{
  if ([[self config] objectForKey:ST_REFRESH])
    return [[[self config] objectForKey:ST_REFRESH] boolValue];
  return NO;
}
- (void)setPeriodicRefresh:(BOOL)periodic
{
  [[self config] setObject:[NSNumber numberWithBool:periodic] forKey:ST_REFRESH];
}
- (NSTimeInterval)refreshInterval
{
  if ([[self config] objectForKey:ST_REFRESH_INTERVAL])
    return [[self config] integerForKey:ST_REFRESH_INTERVAL];
  return 60 * 30;
}
- (void)setRefreshInterval:(NSTimeInterval)interval
{
  [[self config] setInteger:interval forKey:ST_REFRESH_INTERVAL];
}
- (void)config:(ConfigManager *)config dataDidChangedForKey:(NSString *)key
{
  if (config == [self config] && [key isEqualToString:ST_ENABLED] && [self enabled]) {
    [self read];
    [self initTimer];
  }
}

- (void)parseData
{
  if ([_tree parseData:[_resource data]]) {
    [self performSelectorOnMainThread:@selector(fillWithElements:) withObject:[_tree components] waitUntilDone:NO];
    NSLog(@"iCalStore from %@ : loaded %d appointment(s)", [_url anonymousAbsoluteString], [[self events] count]);
    NSLog(@"iCalStore from %@ : loaded %d tasks(s)", [_url anonymousAbsoluteString], [[self tasks] count]);
  } else
    NSLog(@"Couldn't parse data from %@", [_url anonymousAbsoluteString]);
}
- (void)initTimer
{
  if (nil != _refreshTimer) {
    [_refreshTimer invalidate];
    DESTROY(_refreshTimer);
  }
  if ([self periodicRefresh]) {
    _refreshTimer = [[NSTimer alloc] initWithFireDate:nil
				             interval:[self refreshInterval]
                   			       target:self
				             selector:@selector(refreshData:) 
				             userInfo:nil 
				              repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_refreshTimer forMode:NSDefaultRunLoopMode];
    NSLog(@"Store %@ will refresh every %d seconds", [self description], (int)[self refreshInterval]);
  } else {
    NSLog(@"Store %@ automatic refresh disabled", [self description]);
  }
}
- (void)doRead
{
  if ([_resource get])
    [self parseData];
  else
    [self setEnabled:NO];
}
@end
