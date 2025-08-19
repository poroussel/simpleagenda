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

static NSString *logKey = @"GroupDAVStore";

@interface GroupDAVStore : MemoryStore <AgendaStore>
{
  NSURL *_url;
  WebDAVResource *_calendar;
  WebDAVResource *_task;
  NSMutableDictionary *_uidhref;
  NSMutableDictionary *_hreftree;
  NSMutableDictionary *_hrefresource;
  NSMutableArray *_modifiedhref;
  NSString *_username;
  NSString *_password;
}
@end

@interface GroupDAVStore (WellKnownLookups)

- (NSURL*)calendarURLFromRootOfServer:(NSURL *)originalURL
				error:(NSError **)error;
- (NSError *)unableToFindCalendarError:(NSString *)message;
- (NSError *)reportGroupDAVError:(NSString *)title
			 message:(NSString *)message;
- (void)reportError:(NSError *)error;

@end

@interface GroupDAVDialog : NSObject
{
  IBOutlet id panel;
  IBOutlet id name;
  IBOutlet id url;
  IBOutlet id usernameField;
  IBOutlet id passwordField;
  IBOutlet id cancel;
  IBOutlet id ok;
  IBOutlet id check;
  IBOutlet id calendar;
  IBOutlet id task;
}
- (BOOL)show;
- (NSString *)url;
- (NSString *)username;
- (NSString *)password;
- (NSString *)calendar;
- (NSString *)task;
- (void)selectItem:(id)sender;
- (void)checkDirectories;
- (NSError *)reportGroupDAVError:(NSString *)title message:(NSString *)message;
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
    [usernameField setStringValue:@""];
    [passwordField setStringValue:@""];
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
    [self checkDirectories];
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

- (NSError *)unauthorizedAccessError
{
  return [self reportGroupDAVError: @"Unauthorized"
			   message: @"Username and password are incorrect."];
}

- (NSError *)unableToFindCalendarError:(NSString *)message
{
  return [self reportGroupDAVError: @"Unable to find your calendar"
			   message: message];
}

- (NSError *)reportGroupDAVError:(NSString *)title message:(NSString *)message
{
  id userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
				title,  NSLocalizedDescriptionKey,
			      message, NSLocalizedFailureReasonErrorKey,
			      nil];

  return [NSError errorWithDomain: @"GroupDAVStoreErrorDomain"
			     code: 100
			 userInfo: userInfo];
}

- (void)reportError:(NSError *)error
{
  NSRunAlertPanel([error localizedDescription],
		  [error localizedFailureReason],
		  @"OK",
		  nil,
		  nil);
  [self updateOK];
}

- (NSURL*)calendarURLFromRootOfServer:(NSURL *)originalURL error:(NSError **)error
{
  id wellKnownURL = [originalURL URLByAppendingPathComponent:@".well-known/caldav"];
  id resource = [[WebDAVResource alloc] initWithURL:wellKnownURL
					   username:[usernameField stringValue]
					   password:[passwordField stringValue]];
  NSString *getUserPrincipalBody = @"<?xml version=\"1.0\" encoding=\"utf-8\"?><d:propfind xmlns:d=\"DAV:\"><d:prop><d:current-user-principal/></d:prop></d:propfind>";
  NSString *getCalendarHomeSetBody = @"<?xml version=\"1.0\" encoding=\"utf-8\"?><d:propfind xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\"><d:self/><d:prop><c:calendar-home-set /></d:prop></d:propfind>";

  [resource propfind:[getUserPrincipalBody dataUsingEncoding:NSUTF8StringEncoding] attributes:[NSDictionary dictionaryWithObject:@"Infinity" forKey:@"Depth"]];
  if (([resource httpStatus] == 401) ||
      ([resource httpStatus] == 403)) {
    if (error) {
      *error = [self unauthorizedAccessError];
      [resource release];
      return nil;
    }
  }
  if ([resource data] == nil) {
    if (error) {
      *error = [self unableToFindCalendarError:
		       [NSString stringWithFormat:
				   @"No data was returned when "
				 @"trying to find the current user "
				 @"principal at %@",
				 wellKnownURL]];
    }
    [resource release];
    return nil;
  };
  id parser = [GSXMLParser parserWithData:[resource data]];
  [resource release];
  if ([parser parse]) {
    id xpc = [[GSXPathContext alloc] initWithDocument:[[parser document] strippedDocument]];
    GSXPathNodeSet *set = (GSXPathNodeSet *)[xpc evaluateExpression:@"(//response/propstat)[1]/prop/current-user-principal/href/text()"];
    [xpc release];
    if ([set count] == 0) {
      if (error) {
	*error = [self unableToFindCalendarError:
			 [NSString stringWithFormat:
				     @"Could not find current user "
				   @"principal in data returned from "
				   @"%@",
				   wellKnownURL]];
      }
      return nil;
    }
    id node = [set nodeAtIndex:0];
    id principalString = [node content];
    id newURL = [originalURL URLByAppendingPathComponent:principalString];
    if (newURL == nil) {
      if (error) {
	*error = [self unableToFindCalendarError:
			 [NSString stringWithFormat:
				     @"The current user "
				   @"principal returned from "
				   @"%@"
				   @" is not a valid URL path.",
				   wellKnownURL]];
      }
      return nil;
    }
    resource = [[WebDAVResource alloc] initWithURL:newURL
					  username:[usernameField stringValue]
					  password:[passwordField stringValue]];
    [resource propfind:[getCalendarHomeSetBody dataUsingEncoding:NSUTF8StringEncoding] attributes:[NSDictionary dictionaryWithObject:@"Infinity" forKey:@"Depth"]];
    if ([resource data] == nil) {
      if (error) {
	*error = [self unableToFindCalendarError:
			 [NSString stringWithFormat:
				     @"No data was returned when "
				   @"trying to find your home  "
				   @"calendar set at %@",
				   newURL]];
      }
      [resource release];
      return nil;
    };
    parser = [GSXMLParser parserWithData:[resource data]];
    [resource release];
    if ([parser parse]) {
      xpc = [[GSXPathContext alloc] initWithDocument:[[parser document] strippedDocument]];
      set = (GSXPathNodeSet *)[xpc evaluateExpression:@"(//response/propstat)[1]/prop/calendar-home-set/href/text()"];
      [xpc release];
      if ([set count] == 0) {
	if (error) {
	  *error = [self unableToFindCalendarError:
			   [NSString stringWithFormat:
				       @"Could not find home calendar "
				     @"set in data returned from %@",
				     wellKnownURL]];
	}
	return nil;
      }
      node = [set nodeAtIndex:0];
      id homeSetString = [node content];
      newURL = [originalURL URLByAppendingPathComponent:homeSetString];
      if (newURL == nil) {
	if (error) {
	  *error = [self unableToFindCalendarError:
			   [NSString stringWithFormat:
				       @"Home calendar set"
				     @"discovered via %@ "
				     @"is not a valid URL path.",
				     wellKnownURL]];
	}
	return nil;
      }
      return newURL;
    }
    else {
      if (error) {
	*error = [self unableToFindCalendarError:
			 [NSString stringWithFormat:
				     @"Couldn't parse the response to "
				   @"a home calendar set request at "
				   @"%@",
				   newURL]];
      }
      return nil;
    }
  }
  else {
    if (error) {
      *error = [self unableToFindCalendarError:
		       [NSString stringWithFormat:
				   @"Couldn't parse the response to "
				 @"a get user principal request at %@",
				 wellKnownURL]];
    }
    return nil;
  }
}

- (void)checkDirectories
{
  int i;
  WebDAVResource *resource;
  GSXMLParser *parser;
  NSString *body = @"<?xml version=\"1.0\" encoding=\"utf-8\"?><propfind xmlns=\"DAV:\"><prop><getlastmodified/><executable/><resourcetype/></prop></propfind>";
  GSXPathContext *xpc;
  GSXPathNodeSet *set;
  id originalURL = [NSURL URLWithString:[url stringValue]];
  id newURL = nil;

  if (originalURL == nil) {
    [self updateOK];
    return;
  }

  [self clearPopUps];

  if ([[originalURL path] length] == 0) {
    NSError *error = nil;
    newURL = [self calendarURLFromRootOfServer:originalURL error:&error];
    if (newURL == nil) {
      [self reportError:error];
      return;
    }
  }
  else {
    newURL = originalURL;
  }
  resource = [[WebDAVResource alloc] initWithURL:newURL
					username:[usernameField stringValue]
					password:[passwordField stringValue]];
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
      set = (GSXPathNodeSet *)[xpc evaluateExpression:@"//response[propstat/prop/resourcetype/calendar]/href/text()"];
      for (i = 0; i < [set count]; i++) {
	[calendar addItemWithTitle:[[set nodeAtIndex:i] content]];
	[task addItemWithTitle:[[set nodeAtIndex:i] content]];
      }
      RELEASE(xpc);
      if ([calendar numberOfItems] > 0)
	[calendar selectItemAtIndex:1];
      if ([task numberOfItems] > 0)
	[task selectItemAtIndex:1];
    }
  }
  [resource release];
  [self updateOK];
}
- (NSString *)url
{
  return [url stringValue];
}
- (NSString *)username
{
  return [usernameField stringValue];
}
- (NSString *)password
{
  return [passwordField stringValue];
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
    NSDebugLLog(logKey, @"GroupDAVStore initWithName %@", name);
    _uidhref = [[NSMutableDictionary alloc] initWithCapacity:512];
    _hreftree = [[NSMutableDictionary alloc] initWithCapacity:512];
    _hrefresource = [[NSMutableDictionary alloc] initWithCapacity:512];
    _modifiedhref = [NSMutableArray new];
    _url = [[NSURL alloc] initWithString:[[self config] objectForKey:ST_URL]];
    _username = [[[self config] objectForKey:ST_USERNAME] copy];
    _password = [[[self config] objectForKey:ST_PASSWORD] copy];
    if (_username == nil) {
      _username = [[_url user] copy];
    }
    if (_password == nil) {
      _password = [[_url password] copy];
    }

    _calendar = nil;
    _task = nil;
    if ([[self config] objectForKey:ST_CALENDAR_URL]) {
      _calendar = [[WebDAVResource alloc] initWithURL:[[NSURL alloc] initWithString:[[self config] objectForKey:ST_CALENDAR_URL]] username: _username password: _password];
      NSDebugLLog(logKey, @"GroupDAVStore calendar URL %@", [[_calendar url] anonymousAbsoluteString]);
    }
    if ([[self config] objectForKey:ST_TASK_URL]) {
      _task = [[WebDAVResource alloc] initWithURL:[[NSURL alloc] initWithString:[[self config] objectForKey:ST_TASK_URL]] username: _username password: _password];
      NSDebugLLog(logKey, @"GroupDAVStore task URL %@", [[_task url] anonymousAbsoluteString]);
    }
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
    cm = [[ConfigManager alloc] initForKey:name];
    [cm setObject:[dialog url] forKey:ST_URL];
    [cm setObject:[dialog username] forKey:ST_USERNAME];
    [cm setObject:[dialog password] forKey:ST_PASSWORD];
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
  [_username release];
  [_password release];
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
  resource = [[WebDAVResource alloc] initWithURL:url
					username:_username
					password:_password];
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
- (NSArray *)itemsUnderRessource:(WebDAVResource *)resource
{
  int i;
  GSXMLParser *parser;
  NSMutableArray *result;
  GSXPathContext *xpc;
  GSXPathNodeSet *set;
  NSURL *elementURL;

  NSDebugLLog(logKey, @"itemsUnderRessource %@", [[resource url] anonymousAbsoluteString]);
  if (![resource propfind:[PROPFINDGETETAG dataUsingEncoding:NSUTF8StringEncoding]
		attributes:[NSDictionary dictionaryWithObject:@"1" forKey:@"Depth"]])
    return nil;
  result = [NSMutableArray arrayWithCapacity:256];
  parser = [GSXMLParser parserWithData:[resource data]];
  if ([parser parse]) {
    xpc = [[GSXPathContext alloc] initWithDocument:[[parser document] strippedDocument]];
    set = (GSXPathNodeSet *)[xpc evaluateExpression:EXPRGETHREF];
    NSDebugLLog(logKey, @"found %lu item(s)", [set count]);
    for (i = 0; i < [set count]; i++) {
      elementURL = [NSURL URLWithString:[[set nodeAtIndex:i] content] possiblyRelativeToURL:[resource url]];
      if (elementURL) {
	[result addObject:elementURL];
	NSDebugLLog(logKey, @" * items #%d : %@", i, [elementURL anonymousAbsoluteString]);
      }
    }
    RELEASE(xpc);
  } else {
    NSLog(@"XML parsing failed...");
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
    element = [[WebDAVResource alloc] initWithURL:href
					 username:_username
					 password:_password];
    tree = [iCalTree new];
    if ([element get] && [tree parseData:[element data]]) {
      components = [tree components];
      if ([components count] > 0) {
	[loadedData unionSet:components];
	[_hreftree setObject:tree forKey:href];
	[_hrefresource setObject:element forKey:href];
	[_uidhref setObject:href forKey:[[components anyObject] UID]];
      }
    } else {
      NSLog(@"GroupDAVStore add : couldn't read item at %@", [href anonymousAbsoluteString]);
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

  NSDebugLLog(logKey, @"GroupDAVStore doRead");
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
