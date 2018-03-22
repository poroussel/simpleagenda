#import <AppKit/AppKit.h>
#import <GNUstepBase/GSXML.h>
#import "Event.h"
#import "Task.h"
#import "AgendaStore.h"
#import "WebDAVResource.h"
#import "iCalTree.h"
#import "NSString+SimpleAgenda.h"
#import "InvocationOperation.h"
#import "StoreManager.h"
#import "defines.h"

@interface GroupDAVStore : MemoryStore <AgendaStore>
{
  NSURL *_url;
  WebDAVResource *_calendar;
  WebDAVResource *_task;
  NSMutableDictionary *_uidhref;
  NSMutableDictionary *_hreftree;
  NSMutableDictionary *_hrefresource;
  NSMutableArray *_modifiedhref;
}
@end

@interface GroupDAVDialog : NSObject
{
  IBOutlet id panel;
  IBOutlet id name;
  IBOutlet id url;
  IBOutlet id cancel;
  IBOutlet id ok;
  IBOutlet id check;
  IBOutlet id calendar;
  IBOutlet id task;
}
- (BOOL)show;
- (NSString *)url;
- (NSString *)calendar;
- (NSString *)task;
- (void)selectItem:(id)sender;
@end
@implementation GroupDAVDialog
- (void)clearPopUps
{
  [calendar removeAllItems];
  [task removeAllItems];
  [calendar addItemWithTitle:@"None"];
  [task addItemWithTitle:@"None"];
}
- (id)initWithName:(NSString *)storeName
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"GroupDAV" owner:self])
      return nil;
    [name setStringValue:storeName];
    [url setStringValue:@"http://"];
    [self clearPopUps];
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
- (void)buttonClicked:(id)sender
{
  if (sender == cancel)
    [NSApp stopModalWithCode:0];
  else if (sender == ok)
    [NSApp stopModalWithCode:1];
  else if (sender == check)
    [self controlTextDidEndEditing:nil];
}

- (void)updateOK
{
  if ([calendar indexOfSelectedItem] > 0 || [task indexOfSelectedItem] > 0)
    [ok setEnabled:YES];
  else
    [ok setEnabled:NO];
}
- (void)selectItem:(id)sender
{
  [self updateOK];
}
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  int i;
  WebDAVResource *resource;
  GSXMLParser *parser;
  NSString *body = @"<?xml version=\"1.0\" encoding=\"utf-8\"?><propfind xmlns=\"DAV:\"><prop><getlastmodified/><executable/><resourcetype/></prop></propfind>";
  GSXPathContext *xpc;
  GSXPathNodeSet *set;

  [self clearPopUps];
  if ([[url stringValue] isValidURL]) {
    resource = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:[url stringValue]]];
    if ([resource propfind:[body dataUsingEncoding:NSUTF8StringEncoding] attributes:[NSDictionary dictionaryWithObject:@"Infinity" forKey:@"Depth"]]) {
      parser = [GSXMLParser parserWithData:[resource data]];
      if ([parser parse]) {
	xpc = [[GSXPathContext alloc] initWithDocument:[[parser document] strippedDocument]];
	set = (GSXPathNodeSet *)[xpc evaluateExpression:@"//response[propstat/prop/resourcetype/vevent-collection]/href/text()"];
	for (i = 0; i < [set count]; i++)
	  [calendar addItemWithTitle:[[set nodeAtIndex:i] content]];
	set = (GSXPathNodeSet *)[xpc evaluateExpression:@"//response[propstat/prop/resourcetype/vtodo-collection]/href/text()"];
	for (i = 0; i < [set count]; i++)
	  [task addItemWithTitle:[[set nodeAtIndex:i] content]];
	RELEASE(xpc);
	if ([calendar numberOfItems] > 0)
	  [calendar selectItemAtIndex:1];
	if ([task numberOfItems] > 0)
	  [task selectItemAtIndex:1];
      }
    }
    [resource release];
  }
  [self updateOK];
}
- (NSString *)url
{
  return [url stringValue];
}
- (NSString *)calendar
{
  if ([calendar indexOfItem:[calendar selectedItem]] == 0)
    return nil;
  return [calendar titleOfSelectedItem];
}
- (NSString *)task
{
  if ([task indexOfItem:[task selectedItem]] == 0)
    return nil;
  return [task titleOfSelectedItem];;
}
@end

@interface GroupDAVStore(Private)
- (void)doRead;
- (void)doWrite;
@end

@implementation GroupDAVStore
- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjectsAndKeys:[[NSColor redColor] description], ST_COLOR,
		       [[NSColor whiteColor] description], ST_TEXT_COLOR,
		       [NSNumber numberWithBool:NO], ST_RW,
		       [NSNumber numberWithBool:YES], ST_DISPLAY,
		       [NSNumber numberWithBool:YES], ST_ENABLED,
		       nil, nil];
}

- (id)initWithName:(NSString *)name
{
  self = [super initWithName:name];
  if (self) {
    _uidhref = [[NSMutableDictionary alloc] initWithCapacity:512];
    _hreftree = [[NSMutableDictionary alloc] initWithCapacity:512];
    _hrefresource = [[NSMutableDictionary alloc] initWithCapacity:512];
    _modifiedhref = [NSMutableArray new];
    _url = [[NSURL alloc] initWithString:[[self config] objectForKey:ST_URL]];
    _calendar = nil;
    _task = nil;
    if ([[self config] objectForKey:ST_CALENDAR_URL])
      _calendar = [[WebDAVResource alloc] initWithURL:[[NSURL alloc] initWithString:[[self config] objectForKey:ST_CALENDAR_URL]] authFromURL:_url];
    if ([[self config] objectForKey:ST_TASK_URL])
      _task = [[WebDAVResource alloc] initWithURL:[[NSURL alloc] initWithString:[[self config] objectForKey:ST_TASK_URL]] authFromURL:_url];
    [self read];
    [[NSNotificationCenter defaultCenter] addObserver:self 
					     selector:@selector(configChanged:) 
						 name:SAConfigManagerValueChanged 
					       object:[self config]];
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
  GroupDAVDialog *dialog;
  NSURL *calendarURL = nil;
  NSURL *taskURL = nil;
  NSURL *baseURL;

  dialog = [[GroupDAVDialog alloc] initWithName:name];
  if ([dialog show] == YES) {
    baseURL = [NSURL URLWithString:[dialog url]];
    if ([dialog calendar])
      calendarURL = [NSURL URLWithString:[dialog calendar] possiblyRelativeToURL:baseURL];
    if ([dialog task])
      taskURL = [NSURL URLWithString:[dialog task] possiblyRelativeToURL:baseURL];
    [dialog release];
    cm = [[ConfigManager alloc] initForKey:name];
    [cm setObject:[dialog url] forKey:ST_URL];
    if (calendarURL)
      [cm setObject:[calendarURL absoluteString] forKey:ST_CALENDAR_URL];
    if (taskURL)
      [cm setObject:[taskURL absoluteString] forKey:ST_TASK_URL];
    [cm setObject:[[self class] description] forKey:ST_CLASS];
    [cm setObject:[NSNumber numberWithBool:YES] forKey:ST_RW];
    return YES;
  }
  [dialog release];
  return NO;
}

+ (NSString *)storeTypeName
{
  return @"GroupDAV";
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_url release];
  [_calendar release];
  [_task release];
  [_uidhref release];
  [_hreftree release];
  [_hrefresource release];
  [_modifiedhref release];
  [super dealloc];
}

- (void)refreshData:(NSTimer *)timer
{
  [self read];
}

- (void)add:(Element *)elt
{
  NSURL *url;
  WebDAVResource *resource;
  iCalTree *tree;

  if ([elt isKindOfClass:[Event class]])
    url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", [[_calendar url] absoluteString], [elt UID]]];
  else
    url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", [[_task url] absoluteString], [elt UID]]];
  resource = [[WebDAVResource alloc] initWithURL:url authFromURL:_url];
  tree = [iCalTree new];
  if ([tree add:elt]) {
    [resource put:[tree iCalTreeAsData] attributes:[NSDictionary dictionaryWithObjectsAndKeys:@"text/calendar; charset=utf-8", @"Content-Type", @"*", @"If-None-Match", nil, nil]];
    if ([resource httpStatus] > 199 && [resource httpStatus] < 300)
      /* FIXME : this is extremely slow. We should only load attributes and fetch new or modified elements */
      /* Reloading all data is a way to handle href and uid modification done by the server */
      [self doRead];
    else
      NSLog(@"Error %d writing event to %@", [resource httpStatus], [url anonymousAbsoluteString]);
  }
  [tree release];
  [resource release];
}

- (void)remove:(Element *)elt
{
  NSURL *href = [_uidhref objectForKey:[elt UID]];
  WebDAVResource *resource = [_hrefresource objectForKey:href];

  [resource delete];
  if ([resource httpStatus] == 412) {
    /* FIXME : force a visual refresh ? */
    [resource updateAttributes];
    NSLog(@"Couldn't delete item, it has changed on the server");
  } else {
    [_hrefresource removeObjectForKey:href];
    [_uidhref removeObjectForKey:[elt UID]];
    [super remove:elt];
  }
}

/* FIXME : update the iCal tree iif data was written succesfully */
- (void)update:(Element *)elt
{
  NSString *href = [_uidhref objectForKey:[elt UID]];
  iCalTree *tree = [_hreftree objectForKey:href];

  if ([tree update:(Event *)elt]) {
    [super update:elt];
    [_modifiedhref addObject:href];
    [self write];
  }
}

- (void)read
{
  if ([self enabled])
    [[[StoreManager globalManager] operationQueue] addOperation:[[[InvocationOperation alloc] initWithTarget:self 
												    selector:@selector(doRead) 
												      object:nil] autorelease]];
}

- (void)write
{
  if (![self enabled] || ![self writable])
    return;
  [[[StoreManager globalManager] operationQueue] addOperation:[[[InvocationOperation alloc] initWithTarget:self 
												  selector:@selector(doWrite)
												    object:nil] autorelease]];
}

- (void)configChanged:(NSNotification *)not
{
  NSString *key = [[not userInfo] objectForKey:@"key"];
  if ([key isEqualToString:ST_ENABLED]) {
    if ([self enabled])
      [self read];
  }
}
@end


@implementation GroupDAVStore(Private)
static NSString * const PROPFINDGETETAG = @"<?xml version=\"1.0\" encoding=\"utf-8\"?><propfind xmlns=\"DAV:\"><prop><getetag/></prop></propfind>";
static NSString * const EXPRGETHREF = @"//response[propstat/prop/getetag]/href/text()";
- (NSArray *)itemsUnderRessource:(WebDAVResource *)ressource
{
  int i;
  GSXMLParser *parser;
  NSMutableArray *result;
  GSXPathContext *xpc;
  GSXPathNodeSet *set;
  NSURL *elementURL;

  if (![ressource propfind:[PROPFINDGETETAG dataUsingEncoding:NSUTF8StringEncoding] 
		attributes:[NSDictionary dictionaryWithObject:@"1" forKey:@"Depth"]])
    return nil;
  result = [NSMutableArray arrayWithCapacity:256];
  parser = [GSXMLParser parserWithData:[ressource data]];
  if ([parser parse]) {
    xpc = [[GSXPathContext alloc] initWithDocument:[[parser document] strippedDocument]];
    set = (GSXPathNodeSet *)[xpc evaluateExpression:EXPRGETHREF];
    for (i = 0; i < [set count]; i++) {
      elementURL = [NSURL URLWithString:[[set nodeAtIndex:i] content] possiblyRelativeToURL:[ressource url]];
      if (elementURL)
	[result addObject:elementURL];
    }
    RELEASE(xpc);
  }
  return result;
}

- (void)add:(NSArray *)items toSet:(NSMutableSet *)loadedData
{
  WebDAVResource *element;
  iCalTree *tree;
  NSEnumerator *enumerator;
  NSURL *href;
  NSSet *components;

  enumerator = [items objectEnumerator];
  while ((href = [enumerator nextObject])) {
    element = [[WebDAVResource alloc] initWithURL:href authFromURL:_url];
    tree = [iCalTree new];
    if ([element get] && [tree parseData:[element data]]) {
      components = [tree components];
      if ([components count] > 0) {
	[loadedData unionSet:components];
	[_hreftree setObject:tree forKey:href];
	[_hrefresource setObject:element forKey:href];
	[_uidhref setObject:href forKey:[[components anyObject] UID]];
      }
    }
    [tree release];
    [element release];
  }
}
- (void)doRead
{
  NSMutableSet *loadedData = [[NSMutableSet alloc] initWithCapacity:512];
  BOOL error = NO;
  NSArray *items;

  if (_calendar) {
    items = [self itemsUnderRessource:_calendar];
    if (items)
      [self add:items toSet:loadedData];
    else
      error = YES;
  }
  if (_task && !error) {
    items = [self itemsUnderRessource:_task];
    if (items)
      [self add:items toSet:loadedData];
    else
      error = YES;
  }
  if (error) {
    NSLog(@"Error while reading %@", [self description]);
    [[NSNotificationCenter defaultCenter] postNotificationName:SAErrorReadingStore
							object:self
						      userInfo:[NSDictionary dictionary]];
  } else {
    [self performSelectorOnMainThread:@selector(fillWithElements:) withObject:loadedData waitUntilDone:YES];
    NSLog(@"GroupDAVStore from %@ : loaded %lu appointment(s)", [_url anonymousAbsoluteString], [[self events] count]);
    NSLog(@"GroupDAVStore from %@ : loaded %lu tasks(s)", [_url anonymousAbsoluteString], [[self tasks] count]);
  }
  [loadedData release];
}

- (void)doWrite
{
  NSDictionary *attr = [NSDictionary dictionaryWithObject:@"text/calendar; charset=utf-8" forKey:@"Content-Type"];
  NSEnumerator *enumerator;
  WebDAVResource *element;
  iCalTree *tree;
  NSURL *href;
  NSArray *copy;
  BOOL error = NO;

  copy = [_modifiedhref copy];
  enumerator = [copy objectEnumerator];
  while ((href = [enumerator nextObject])) {
    element = [_hrefresource objectForKey:href];
    tree = [_hreftree objectForKey:href];
    if ([element put:[tree iCalTreeAsData] attributes:attr]) {
      /* Read it back to update the attributes */ 
      /* FIXME : RFC says we should update the list instead */
      [element updateAttributes];
      [_modifiedhref removeObject:href];
      NSLog(@"Written %@", [href anonymousAbsoluteString]);
    } else {
      NSLog(@"Unable to write to %@", [href anonymousAbsoluteString]);
      error = YES;
    }
  }
  if (error) {
    NSLog(@"Calendar %@ will be made read only and data reread", [self description]);
    [[NSNotificationCenter defaultCenter] postNotificationName:SAErrorWritingStore 
							object:self
						      userInfo:[NSDictionary dictionary]];
  }
  [copy release];
}
@end
