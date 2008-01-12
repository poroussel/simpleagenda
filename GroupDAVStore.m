#import <Foundation/Foundation.h>
#import <GNUstepBase/GSXML.h>
#import "GNUstepBase/GSMime.h"
#import "Event.h"
#import "Task.h"
#import "GroupDAVStore.h"
#import "WebDAVResource.h"
#import "iCalTree.h"
#import "defines.h"

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
  BOOL isURL;
}
- (BOOL)show;
- (NSString *)url;
- (NSString *)calendar;
- (NSString *)task;
- (void)selectItem:(id)sender;
@end
@implementation GroupDAVDialog
- (id)initWithName:(NSString *)storeName
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"GroupDAV" owner:self])
      return nil;
    [name setStringValue:storeName];
    [url setStringValue:@"http://"];
    [calendar removeAllItems];
    [task removeAllItems];
    isURL = NO;
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

- (void)controlTextDidChange:(NSNotification *)notification
{
  NS_DURING
    {
      isURL = [NSURL stringIsValidURL:[url stringValue]];
    }
  NS_HANDLER
    {
      isURL = NO;
    }
  NS_ENDHANDLER
}
- (void)updateOK
{
  if ([calendar indexOfSelectedItem] != -1 || [task indexOfSelectedItem] != -1)
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
  NSData *propfind;
  NSString *body = @"<?xml version=\"1.0\" encoding=\"utf-8\"?><propfind xmlns=\"DAV:\"><prop><getlastmodified/><executable/><resourcetype/></prop></propfind>";
  GSXPathContext *xpc;
  GSXPathNodeSet *set;

  [calendar removeAllItems];
  [task removeAllItems];
  if (isURL) {
    resource = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:[url stringValue]]];
    propfind = [resource propfind:[body dataUsingEncoding:NSUTF8StringEncoding] attributes:[NSDictionary dictionaryWithObject:@"Infinity" forKey:@"Depth"]];
    parser = [GSXMLParser parserWithData:propfind];
    if ([parser parse]) {
      xpc = [[GSXPathContext alloc] initWithDocument:[[parser document] strippedDocument]];
      set = (GSXPathNodeSet *)[xpc evaluateExpression:@"//response[propstat/prop/resourcetype/vevent-collection]/href/text()"];
      for (i = 0; i < [set count]; i++)
	[calendar addItemWithTitle:[[set nodeAtIndex:i] content]];
      set = (GSXPathNodeSet *)[xpc evaluateExpression:@"//response[propstat/prop/resourcetype/vtodo-collection]/href/text()"];
      for (i = 0; i < [set count]; i++)
	[task addItemWithTitle:[[set nodeAtIndex:i] content]];
      [xpc release];
    }
    [propfind release];
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
  return [calendar titleOfSelectedItem];
}
- (NSString *)task
{
  return [task titleOfSelectedItem];;
}
@end

@interface GroupDAVStore(Private)
- (void)initTimer:(id)object;
- (void)initStoreAsync:(id)object;
- (void)fetchData:(id)object;
@end

@implementation GroupDAVStore
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
    _uidhref = [[NSMutableDictionary alloc] initWithCapacity:512];
    _hreftree = [[NSMutableDictionary alloc] initWithCapacity:512];
    _hrefresource = [[NSMutableDictionary alloc] initWithCapacity:512];
    _modifiedhref = [NSMutableArray new];
   [NSThread detachNewThreadSelector:@selector(initStoreAsync:) toTarget:self withObject:nil];
  }
  return self;
}

+ (BOOL)registerWithName:(NSString *)name
{
  ConfigManager *cm;
  GroupDAVDialog *dialog;
  NSURL *calendarURL;
  NSURL *taskURL;
  NSURL *baseURL;

  dialog = [[GroupDAVDialog alloc] initWithName:name];
  if ([dialog show] == YES) {
    baseURL = [NSURL URLWithString:[dialog url]];
    calendarURL = [NSURL URLWithString:[dialog calendar] possiblyRelativeToURL:baseURL];
    taskURL = [NSURL URLWithString:[dialog task] possiblyRelativeToURL:baseURL];
    [dialog release];
    cm = [[ConfigManager alloc] initForKey:name withParent:nil];
    [cm setObject:[dialog url] forKey:ST_URL];
    if (calendarURL)
      [cm setObject:[calendarURL description] forKey:ST_CALENDAR_URL];
    if (taskURL)
      [cm setObject:[taskURL description] forKey:ST_TASK_URL];
    [cm setObject:[[self class] description] forKey:ST_CLASS];
    [cm setObject:[NSNumber numberWithBool:YES] forKey:ST_RW];
    return YES;
  }
  [dialog release];
  return NO;
}

+ (NSString *)storeTypeName
{
  return @"GroupDAV store";
}

- (void)dealloc
{
  [self write];
  DESTROY(_url);
  DESTROY(_calendar);
  DESTROY(_task);
  DESTROY(_uidhref);
  DESTROY(_hreftree);
  DESTROY(_hrefresource);
  DESTROY(_modifiedhref);
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
  resource = [[WebDAVResource alloc] initWithURL:url];
  if ([_url user])
    [resource setUser:[_url user] password:[_url password]];
  tree = [iCalTree new];
  if ([tree add:elt]) {
    [resource put:[tree iCalTreeAsData] attributes:[NSDictionary dictionaryWithObjectsAndKeys:@"text/calendar; charset=utf-8", @"Content-Type", @"*", @"If-None-Match", nil, nil]];
    if ([resource httpStatus] > 199 && [resource httpStatus] < 300) {
      if ([resource location])
	url = [NSURL URLWithString:[resource location] possiblyRelativeToURL:_url];
      [_hreftree setObject:tree forKey:[url absoluteString]];
      [_hrefresource setObject:resource forKey:[url absoluteString]];
      [_uidhref setObject:[url absoluteString] forKey:[elt UID]];
      /* FIXME : force a visual refresh ? */
      [resource updateAttributes];
      [super add:elt];
    }
  }
  [tree release];
  [resource release];
}

- (void)remove:(Element *)elt
{
  NSString *href = [_uidhref objectForKey:[elt UID]];
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

- (BOOL)read
{
  /* FIXME : this should call something else, same thing for iCalStore ? */
  /* This version won't work for deleted elements etc */
  [self fetchData:nil];
  return YES;
}

- (BOOL)write
{
  NSEnumerator *enumerator;
  WebDAVResource *element;
  iCalTree *tree;
  NSString *href;
  NSArray *copy;
  NSData *data;

  copy = [_modifiedhref copy];
  enumerator = [copy objectEnumerator];
  while ((href = [enumerator nextObject])) {
    element = [_hrefresource objectForKey:href];
    tree = [_hreftree objectForKey:href];
    [element put:[tree iCalTreeAsData] attributes:[NSDictionary dictionaryWithObject:@"text/calendar; charset=utf-8" forKey:@"Content-Type"]];
    /* Read it back to update the attributes */ 
    /* FIXME : RFC says we should update the list instead */
    data = [element get];
    DESTROY(data);
    [_modifiedhref removeObject:href];
    NSLog(@"Written %@", href);
  }
  [copy release];
  return YES;
}
@end


@implementation GroupDAVStore(Private)
- (void)initTimer:(id)object
{
}
- (void)initStoreAsync:(id)object
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  _url = [[NSURL alloc] initWithString:[_config objectForKey:ST_URL]];
  if ([_config objectForKey:ST_CALENDAR_URL]) {
    _calendar = [[WebDAVResource alloc] initWithURL:[[NSURL alloc] initWithString:[_config objectForKey:ST_CALENDAR_URL]]];
    if ([_url user])
      [_calendar setUser:[_url user] password:[_url password]];
  } else
    _calendar = nil;
  if ([_config objectForKey:ST_TASK_URL]) {
    _task = [[WebDAVResource alloc] initWithURL:[[NSURL alloc] initWithString:[_config objectForKey:ST_TASK_URL]]];
    if ([_url user])
      [_task setUser:[_url user] password:[_url password]];
  } else
    _task = nil;
  [self performSelectorOnMainThread:@selector(fetchData:) withObject:nil waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(initTimer:) withObject:nil waitUntilDone:YES];
  [pool release];
}

- (void)fetchList:(NSArray *)items
{
  WebDAVResource *element;
  NSData *ical;
  iCalTree *tree;
  NSEnumerator *enumerator;
  NSString *href;

  enumerator = [items objectEnumerator];
  while ((href = [enumerator nextObject])) {
    element = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:href]];
    if ([_url user])
      [element setUser:[_url user] password:[_url password]];
    tree = [iCalTree new];
    ical = [element get];
    if (ical && [tree parseData:ical]) {
      [self fillWithElements:[tree components]];
      [_hreftree setObject:tree forKey:href];
      [_hrefresource setObject:element forKey:href];
      [_uidhref setObject:href forKey:[[[tree components] anyObject] UID]];
    }
    DESTROY(ical);
    [tree release];
    [element release];
  }
}
- (void)fetchData:(id)object
{
  if (_calendar)
    [self fetchList:AUTORELEASE([_calendar listICalItems])];
  if (_task)
    [self fetchList:AUTORELEASE([_task listICalItems])];
  NSLog(@"GroupDAVStore from %@ : loaded %d appointment(s)", [_url absoluteString], [[self events] count]);
  NSLog(@"GroupDAVStore from %@ : loaded %d tasks(s)", [_url absoluteString], [[self tasks] count]);
}
@end
