#import <Foundation/Foundation.h>
#import <GNUstepBase/GSXML.h>
#import "Event.h"
#import "Task.h"
#import "iCalStore.h"
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
- (void)setError:(NSString *)errorText;
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
  [NSApp stopModalWithCode:1];
}
- (void)cancelClicked:(id)sender
{
  [NSApp stopModalWithCode:0];
}
- (void)setError:(NSString *)errorText
{
  [error setStringValue:errorText];
  [warning setHidden:NO];
}
- (void)controlTextDidChange:(NSNotification *)notification
{
  NS_DURING
    {
      NSURL *storeUrl = [NSURL URLWithString:[url stringValue]];
      [ok setEnabled:(storeUrl != nil)];
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
+ (NSURL *)getRealURL:(NSURL *)url;
+ (BOOL)canReadFromURL:(NSURL *)url;
+ (BOOL)canWriteToURL:(NSURL *)url;
- (GSXMLNode *)getLastModifiedElement:(GSXMLNode *)node;
- (NSDate *)getLastModified;
- (BOOL)needsRefresh;
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
    _retrievedData = nil;
    _lastModified = nil;
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

  dialog = [[iCalStoreDialog alloc] initWithName:name];
 error:
  if ([dialog show] == YES) {
    storeURL = [iCalStore getRealURL:[NSURL URLWithString:[dialog url]]];
    writable = YES;
    if ([iCalStore canWriteToURL:storeURL] == NO) {
      writable = NO;
      if ([iCalStore canReadFromURL:storeURL] == NO) {
	[dialog setError:@"Unable to read at this url"];
	goto error;
      }
    }
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
  [_url release];
  [_lastModified release];
  [_tree release];
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

/*
 * FIXME : we should probably write asynchronously on
 * every change or every x minutes.
 * Do we need to read before writing ?
 */
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
  if ([self needsRefresh]) {
    [self fetchData:nil];
    return YES;
  }
  return NO;
}

- (BOOL)write
{
  NSData *data;
  NSURLHandle *handle;

  if (![self modified] || ![self writable])
    return YES;
  data = [[_tree iCalTreeAsString] dataUsingEncoding:NSUTF8StringEncoding];
  if (data) {
    handle = [_url URLHandleUsingCache:NO];
    [handle writeProperty:@"PUT" forKey:GSHTTPPropertyMethodKey];
    [handle writeData:data];
    [handle loadInForeground];
    if ([handle status] == NSURLHandleLoadSucceeded) {
      [self setModified:NO];
      NSLog(@"iCalStore written to %@", [_url absoluteString]);
      return YES;
    }
    [self setWritable:NO];
    NSLog(@"Unable to write to %@, make this store read only", [_url absoluteString]);
    return NO;
  }
  return YES;
}
@end


@implementation iCalStore(NSURLClient)
- (void)URL:(NSURL *)sender resourceDataDidBecomeAvailable:(NSData *)newBytes
{
  [_retrievedData appendData:newBytes];
}
- (void)URL:(NSURL *)sender resourceDidFailLoadingWithReason:(NSString *)reason
{
  NSLog(@"resourceDidFailLoadingWithReason %@", reason);
  [_retrievedData release];
}
- (void)URLResourceDidCancelLoading:(NSURL *)sender
{
  NSLog(@"URLResourceDidCancelLoading");
  [_retrievedData release];
}
- (void)URLResourceDidFinishLoading:(NSURL *)sender
{
  [self parseData:_retrievedData];
  [_retrievedData release];
}
@end

@implementation iCalStore(Private)
+ (NSURL *)getRealURL:(NSURL *)url
{
  NSString *location;

  location = [url propertyForKey:@"Location"];
  if (location) {
    NSLog(@"Redirected to %@", location);
    return [iCalStore getRealURL:[NSURL URLWithString:location]];
  }
  return url;
}
+ (BOOL)canReadFromURL:(NSURL *)url
{
  if ([url resourceDataUsingCache:NO] == nil)
      return NO;
  return YES;
}

+ (BOOL)canWriteToURL:(NSURL *)url
{
  BOOL ret;
  NSURL *tmp = AUTORELEASE([[NSURL alloc] initWithString:@"sa.write" relativeToURL:url]);

  [tmp setProperty:@"PUT" forKey:GSHTTPPropertyMethodKey];
  ret = [tmp setResourceData:[NSData data]];
  if (ret) {
    [tmp setProperty:@"DELETE" forKey:GSHTTPPropertyMethodKey];
    [tmp setResourceData:nil];
    return YES;
  }
  return NO;
}
- (BOOL)needsRefresh
{
  NSDate *lm = [self getLastModified];

  if (!_lastModified) {
    if (lm)
      _lastModified = [lm copy];
    return YES;
  }
  if (!lm)
    return YES;
  if ([_lastModified compare:lm] == NSOrderedAscending) {
    [_lastModified release];
    _lastModified = [lm copy];
    return YES;
  }
  return NO;
}
- (GSXMLNode *)getLastModifiedElement:(GSXMLNode *)node
{
  GSXMLNode *inter;

  while (node) {
    if ([node type] == [GSXMLNode typeFromDescription:@"XML_ELEMENT_NODE"] && 
	[@"getlastmodified" isEqualToString:[node name]])
      return node;
    if ([node firstChild]) {
      inter = [self getLastModifiedElement:[node firstChild]];
      if (inter)
	return inter;
    }
    node = [node next];
  }
  return nil;
}
- (NSDate *)getLastModified
{
  GSXMLParser *parser;
  GSXMLNode *node;
  NSDate *date;
  NSData *data;

  [_url setProperty:@"PROPFIND" forKey:GSHTTPPropertyMethodKey];
  data = [_url resourceDataUsingCache:NO];
  [_url setProperty:@"GET" forKey:GSHTTPPropertyMethodKey];
  if (data) {
    parser = [GSXMLParser parserWithData:data];
    if ([parser parse]) {
      node = [self getLastModifiedElement:[[parser document] root]];
      date = [NSDate dateWithNaturalLanguageString:[node content]];
      return date;
    }
  }
  return nil;
}
- (void)fetchData:(id)object
{
  _retrievedData = [[NSMutableData alloc] initWithCapacity:16384];
  [_url loadResourceDataNotifyingClient:self usingCache:NO]; 
}
- (void)parseData:(NSData *)data
{
  NSString *text;

  text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (text && [_tree parseString:text]) {
    [self fillWithElements:[_tree components]];
    NSLog(@"iCalStore from %@ : loaded %d appointment(s)", [_url absoluteString], [[self events] count]);
    NSLog(@"iCalStore from %@ : loaded %d tasks(s)", [_url absoluteString], [[self tasks] count]);
  } else
    NSLog(@"Couldn't parse data from %@", [_url absoluteString]);
  if (text)
    [text release];
}
- (void)initTimer:(id)object
{
  if ([_config objectForKey:ST_REFRESH])
    _minutesBeforeRefresh = [_config integerForKey:ST_REFRESH];
  else
    _minutesBeforeRefresh = 60;
  _refreshTimer = [[NSTimer alloc] initWithFireDate:nil
				   interval:_minutesBeforeRefresh * 60
				   target:self selector:@selector(refreshData:) 
				   userInfo:nil repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:_refreshTimer forMode:NSDefaultRunLoopMode];
}
- (void)initStoreAsync:(id)object
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSURL *realURL;

  realURL = [iCalStore getRealURL:[NSURL URLWithString:[_config objectForKey:ST_URL]]];
  if (realURL == nil) {
    NSLog(@"%@ isn't a valid url", [_config objectForKey:ST_URL]);
    [self release];
    [pool release];
    return;
  }
  _url = [realURL copy];
  [self performSelectorOnMainThread:@selector(fetchData:) withObject:nil waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(initTimer:) withObject:nil waitUntilDone:YES];
  [pool release];
}
@end
