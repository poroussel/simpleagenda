#import <AppKit/AppKit.h>
#import "Event.h"
#import "Task.h"
#import "AgendaStore.h"
#import "WebDAVResource.h"
#import "iCalTree.h"
#import "defines.h"

@interface iCalStore : MemoryStore <SharedStore, ConfigListener>
{
  iCalTree *_tree;
  NSURL *_url;
  NSTimer *_refreshTimer;
  WebDAVResource *_resource;
}
@end

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
  NSURL *tmp;
  WebDAVResource *resource;

  tmp = [NSURL URLWithString:[url stringValue]];
  resource = AUTORELEASE([[WebDAVResource alloc] initWithURL:tmp]);
  readable = [resource readable];
  /* Read will fail if there's no resource yet, try to create an empty one */
  if (!readable) {
    [resource writableWithData:[NSData data]];
    readable = [resource readable];
  }
  if (readable)
    [NSApp stopModalWithCode:1];
  else {
    [error setStringValue:[NSString stringWithFormat:@"Unable to read from this URL : %@", [tmp propertyForKey:NSHTTPPropertyStatusReasonKey]]];
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
      [ok setEnabled:[NSURL stringIsValidURL:[url stringValue]]];
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

@interface iCalStore(Private)
- (void)fetchData;
- (void)parseData:(NSData *)data;
- (void)initTimer;
- (void)initStoreAsync:(id)object;
@end

@implementation iCalStore
- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjectsAndKeys:[[NSColor blueColor] description], ST_COLOR,
		       [[NSColor darkGrayColor] description], ST_TEXT_COLOR,
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
    _url = [[NSURL alloc] initWithString:[_config objectForKey:ST_URL]];
    _resource = [[WebDAVResource alloc] initWithURL:_url];
    [_config registerClient:self forKey:ST_REFRESH];
    [_config registerClient:self forKey:ST_REFRESH_INTERVAL];
    [_config registerClient:self forKey:ST_ENABLED];
    [NSThread detachNewThreadSelector:@selector(initStoreAsync:) toTarget:self withObject:nil];
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
  return @"iCalendar store";
}

- (void)dealloc
{
  [_config unregisterClient:self];
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
  [self fetchData];
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
      NSLog(@"iCalStore written to %@", [_url absoluteString]);
      return YES;
    }
    if ([_resource httpStatus] == 412) {
      NSRunAlertPanel(@"Error : data source modified", @"To prevent losing modifications, this agenda\nwill be updated and marked as read-only. ", @"Ok", nil, nil);
      [self read];
    }
    NSLog(@"Unable to write to %@, make this store read only", [_url absoluteString]);
    [self setWritable:NO];
    return NO;
  }
  return YES;
}

- (BOOL)periodicRefresh
{
  if ([_config objectForKey:ST_REFRESH])
    return [[_config objectForKey:ST_REFRESH] boolValue];
  return NO;
}
- (void)setPeriodicRefresh:(BOOL)periodic
{
  [_config setObject:[NSNumber numberWithBool:periodic] forKey:ST_REFRESH];
}
- (NSTimeInterval)refreshInterval
{
  if ([_config objectForKey:ST_REFRESH_INTERVAL])
    return [_config integerForKey:ST_REFRESH_INTERVAL];
  return 60 * 30;
}
- (void)setRefreshInterval:(NSTimeInterval)interval
{
  [_config setInteger:interval forKey:ST_REFRESH_INTERVAL];
}
- (void)config:(ConfigManager*)config dataDidChangedForKey:(NSString *)key
{
  if ([key isEqualToString:ST_ENABLED] && [self enabled]) {
    [self read];
    [self initTimer];
  }
}
@end


@implementation iCalStore(Private)
- (void)fetchData
{
  if ([self enabled]) {
    if ([_resource get])
      if ([NSThread isMainThread])
	[self parseData:[_resource data]];
      else
	[self performSelectorOnMainThread:@selector(parseData:) withObject:[_resource data] waitUntilDone:NO];
    else
      [self setEnabled:NO];
  }
}
- (void)parseData:(NSData *)data
{
  if ([_tree parseData:data]) {
    [self fillWithElements:[_tree components]];
    NSLog(@"iCalStore from %@ : loaded %d appointment(s)", [_url absoluteString], [[self events] count]);
    NSLog(@"iCalStore from %@ : loaded %d tasks(s)", [_url absoluteString], [[self tasks] count]);
  } else
    NSLog(@"Couldn't parse data from %@", [_url absoluteString]);
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
- (void)initStoreAsync:(id)object
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  [self fetchData];
  [pool release];
}
@end
