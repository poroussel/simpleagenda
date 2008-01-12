#import <Foundation/Foundation.h>
#import "Event.h"
#import "Task.h"
#import "iCalStore.h"
#import "WebDAVResource.h"
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
  NSURL *tmp;
  WebDAVResource *resource;

  tmp = [NSURL URLWithString:[url stringValue]];
  resource = AUTORELEASE([[WebDAVResource alloc] initWithURL:tmp]);
  if ([resource readable])
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
- (void)fetchData:(id)object;
- (void)parseData:(NSData *)data;
- (void)initTimer:(id)object;
- (void)initStoreAsync:(id)object;
@end

@implementation iCalStore
- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
			 [NSArchiver archivedDataWithRootObject:[NSColor blueColor]], ST_COLOR,
			 [NSArchiver archivedDataWithRootObject:[NSColor darkGrayColor]], ST_TEXT_COLOR,
		       [NSNumber numberWithBool:NO], ST_RW,
		       [NSNumber numberWithBool:YES], ST_DISPLAY,
		       nil, nil];
}

- (id)initWithName:(NSString *)name
{
  self = [super initWithName:name];
  if (self) {
    _tree = [iCalTree new];
    [NSThread detachNewThreadSelector:@selector(initStoreAsync:) toTarget:self withObject:nil];
  }
  return self;
}

+ (BOOL)registerWithName:(NSString *)name
{
  ConfigManager *cm;
  iCalStoreDialog *dialog;
  NSURL *storeURL;
  BOOL writable = NO;
  WebDAVResource *resource;
  NSData *data;

  dialog = [[iCalStoreDialog alloc] initWithName:name];
  if ([dialog show] == YES) {
    storeURL = [NSURL URLWithString:[dialog url]];
    resource = [[WebDAVResource alloc] initWithURL:storeURL];
    data = [resource get];
    writable = NO;
    if (data) {
      writable = [resource writableWithData:data];
      [data release];
    }
    [resource release];
    [dialog release];
    cm = [[ConfigManager alloc] initForKey:name withParent:nil];
    [cm setObject:[storeURL description] forKey:ST_URL];
    [cm setObject:[[self class] description] forKey:ST_CLASS];
    [cm setObject:[NSNumber numberWithBool:writable] forKey:ST_RW];
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
  [_refreshTimer invalidate];
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
    if (![_url isFileURL])
      [self write];
  }
}

- (void)remove:(Element *)elt
{
  if ([_tree remove:elt]) {
    [super remove:elt];
    if (![_url isFileURL])
      [self write];
  }
}

- (void)update:(Element *)elt
{
  if ([_tree update:(Event *)elt]) {
    [super update:elt];
    if (![_url isFileURL])
      [self write];
  }
}

- (BOOL)read
{
  [self fetchData:nil];
  return [_resource dataChanged];
}

- (BOOL)write
{
  NSData *data;
  NSData *read;

  if (![self modified] || ![self writable])
    return YES;
  data = [_tree iCalTreeAsData];
  if (data) {
    read = [_resource put:data];
    DESTROY(read);
    if ([_resource status] == NSURLHandleLoadSucceeded) {
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
@end


@implementation iCalStore(Private)
- (void)fetchData:(id)object
{
  [self parseData:AUTORELEASE([_resource get])];
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
- (void)initTimer:(id)object
{
  if ([_config objectForKey:ST_REFRESH])
    _minutesBeforeRefresh = [_config integerForKey:ST_REFRESH];
  else
    _minutesBeforeRefresh = 30;
  _refreshTimer = [[NSTimer alloc] initWithFireDate:nil
				   interval:_minutesBeforeRefresh * 60
				   target:self selector:@selector(refreshData:) 
				   userInfo:nil repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:_refreshTimer forMode:NSDefaultRunLoopMode];
}
- (void)initStoreAsync:(id)object
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  _url = [[NSURL alloc] initWithString:[_config objectForKey:ST_URL]];
  _resource = [[WebDAVResource alloc] initWithURL:_url];
  [self performSelectorOnMainThread:@selector(fetchData:) withObject:nil waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(initTimer:) withObject:nil waitUntilDone:YES];
  [pool release];
}
@end
