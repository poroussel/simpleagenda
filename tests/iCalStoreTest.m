/* -*- objc -*- */

#import "ObjectTesting.h"
#import "AgendaStore.h"
#import "Event.h"
#import "StoreManager.h"
#import "Task.h"
#import "defines.h"

/*
 * No network here : mock:// URLs are served by MockHandle, a small fake
 * WebDAV server keeping one calendar in memory and recording the requests.
 * Requests are sent from the StoreManager operation queue.
 */
static NSLock *serverLock;
static NSMutableArray *requests;
static NSMutableDictionary *forcedStatus;
static NSString *serverBody;
static NSString *serverETag;
static int etagCounter;

@interface MockHandle : NSURLHandle
{
  NSMutableDictionary *_request;
  NSMutableDictionary *_response;
}
@end
@implementation MockHandle
+ (BOOL)canInitWithURL:(NSURL *)url
{
  return [[url scheme] isEqual:@"mock"];
}
+ (NSURLHandle *)cachedHandleForURL:(NSURL *)url
{
  return nil;
}
- (id)initWithURL:(NSURL *)url cached:(BOOL)cached
{
  if ((self = [super initWithURL:url cached:NO])) {
    _request = [NSMutableDictionary new];
    _response = [NSMutableDictionary new];
    [_request setObject:[url absoluteString] forKey:@"url"];
  }
  return self;
}
- (void)dealloc
{
  RELEASE(_request);
  RELEASE(_response);
  [super dealloc];
}
- (BOOL)writeProperty:(id)value forKey:(NSString *)key
{
  [_request setObject:value forKey:[key isEqual:GSHTTPPropertyMethodKey] ? @"method" : key];
  return YES;
}
- (BOOL)writeData:(NSData *)data
{
  [_request setObject:AUTORELEASE([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding])
	       forKey:@"body"];
  return YES;
}
- (NSData *)resourceData
{
  NSString *method = [_request objectForKey:@"method"];
  NSNumber *forced;
  NSString *body = @"";
  int status = 200;

  [serverLock lock];
  [requests addObject:_request];
  forced = [forcedStatus objectForKey:method];
  if (forced) {
    status = [forced intValue];
    [forcedStatus removeObjectForKey:method];
  } else if ([method isEqual:@"GET"]) {
    body = serverBody;
    [_response setObject:serverETag forKey:@"ETag"];
  } else if ([method isEqual:@"PUT"]) {
    status = 204;
    ASSIGN(serverBody, [_request objectForKey:@"body"]);
    ASSIGN(serverETag, ([NSString stringWithFormat:@"\"etag%d\"", ++etagCounter]));
  } else if ([method isEqual:@"PROPFIND"]) {
    status = 207;
    body = [NSString stringWithFormat:@"<?xml version=\"1.0\"?><D:multistatus xmlns:D=\"DAV:\"><D:response><D:propstat><D:prop><D:getetag>%@</D:getetag></D:prop></D:propstat></D:response></D:multistatus>", serverETag];
  }
  [serverLock unlock];
  [_response setObject:[NSNumber numberWithInt:status] forKey:NSHTTPPropertyStatusCodeKey];
  return [body dataUsingEncoding:NSUTF8StringEncoding];
}
- (id)propertyForKey:(NSString *)key
{
  return [_response objectForKey:key];
}
- (id)propertyForKeyIfAvailable:(NSString *)key
{
  return [_response objectForKey:key];
}
@end

/*
 * On errors, StoreManager displays a modal panel which would block the
 * test : replace it to remember the messages.
 */
static NSMutableArray *panels;

@implementation StoreManager(Testing)
- (void)displayPanelFromDictionary:(NSDictionary *)dict
{
  [panels addObject:dict];
}
@end

static NSString * const CALENDAR =
  @"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:test\r\n"
  @"BEGIN:VEVENT\r\nUID:event1\r\nSUMMARY:Server event\r\n"
  @"DTSTART:20240615T100000Z\r\nDURATION:PT1H\r\nEND:VEVENT\r\n"
  @"BEGIN:VTODO\r\nUID:task1\r\nSUMMARY:Server task\r\nEND:VTODO\r\n"
  @"END:VCALENDAR\r\n";
static NSString * const EMPTY_CALENDAR =
  @"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:test\r\nEND:VCALENDAR\r\n";

/*
 * Reads and writes finish on the main thread through
 * -performSelectorOnMainThread:, so the run loop has to be running.
 */
static void waitForOperations(void)
{
  NSOperationQueue *queue = [[StoreManager globalManager] operationQueue];
  NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:10];

  do {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  } while ([[queue operations] count] > 0 && [limit timeIntervalSinceNow] > 0);
}

static void resetServer(NSString *body, NSString *etag)
{
  ASSIGN(serverBody, body);
  ASSIGN(serverETag, etag);
  [requests removeAllObjects];
  [forcedStatus removeAllObjects];
  [panels removeAllObjects];
}

static void forceStatus(NSString *method, int status)
{
  [forcedStatus setObject:[NSNumber numberWithInt:status] forKey:method];
}

static int requestCount(NSString *method)
{
  NSEnumerator *enumerator = [requests objectEnumerator];
  NSDictionary *request;
  int count = 0;

  while ((request = [enumerator nextObject]))
    if ([[request objectForKey:@"method"] isEqual:method])
      count++;
  return count;
}

static NSDictionary *lastRequest(NSString *method)
{
  NSEnumerator *enumerator = [requests reverseObjectEnumerator];
  NSDictionary *request;

  while ((request = [enumerator nextObject]))
    if ([[request objectForKey:@"method"] isEqual:method])
      return request;
  return nil;
}

static BOOL lastPutContains(NSString *text)
{
  return [[lastRequest(@"PUT") objectForKey:@"body"] rangeOfString:text].length > 0;
}

/* The configuration +registerWithName: would save after its dialog */
static id <SharedStore> newStore(NSString *name, BOOL writable)
{
  ConfigManager *cm = AUTORELEASE([[ConfigManager alloc] initForKey:name]);

  [cm setObject:@"mock://example.org/calendar.ics" forKey:ST_URL];
  [cm setObject:[NSNumber numberWithBool:writable] forKey:ST_RW];
  return [NSClassFromString(@"iCalStore") storeNamed:name];
}

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  /*
   * Values are written to this tool's own defaults domain, never to
   * SimpleAgenda's. The domain is removed before and after the test.
   */
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *domain = [[NSProcessInfo processInfo] processName];
  Class cls = NSClassFromString(@"iCalStore");
  id <SharedStore> store;
  Event *event;
  Task *task;

  [ud removePersistentDomainForName:domain];
  serverLock = [NSLock new];
  requests = [NSMutableArray new];
  forcedStatus = [NSMutableDictionary new];
  panels = [NSMutableArray new];
  [NSURLHandle registerURLHandleClass:[MockHandle class]];
  resetServer(CALENDAR, @"\"etag0\"");

  /* Class methods */
  PASS(cls != Nil, "iCalStore class exists");
  PASS([cls isUserInstanciable], "+isUserInstanciable is YES");
  PASS_EQUAL([cls storeTypeName], @"iCalendar", "+storeTypeName works");
  PASS([StoreManager backendForName:@"iCalendar"] == cls,
       "the store is registered as a StoreManager backend");

  /* Defaults */
  store = newStore(@"defaults", NO);
  PASS(store != nil, "+storeNamed: works");
  test_NSObject(@"iCalStore", [NSArray arrayWithObject:store]);
  PASS(![store writable], "the writable state comes from the configuration");
  {
    ConfigManager *cm = AUTORELEASE([[ConfigManager alloc] initForKey:@"urlOnly"]);

    [cm setObject:@"mock://example.org/calendar.ics" forKey:ST_URL];
    PASS(![[cls storeNamed:@"urlOnly"] writable], "a store is read only by default");
  }
  PASS([store displayed] && [store enabled], "a store is displayed and enabled by default");
  PASS(![store modified], "a new store isn't modified");
  PASS([store eventColor] != nil && [store textColor] != nil, "a store has default colors");
  PASS(![store periodicRefresh], "periodic refresh is disabled by default");
  PASS([store refreshInterval] == 1800, "the default refresh interval is 30 minutes");
  PASS([requests count] == 0, "creating a store doesn't send a request");
  PASS([newStore(@"writable", YES) writable], "a store can be configured as writable");

  /* Reading */
  store = newStore(@"read", NO);
  [store read];
  waitForOperations();
  PASS(requestCount(@"GET") == 1, "-read sends a GET");
  PASS_EQUAL([lastRequest(@"GET") objectForKey:@"url"], @"mock://example.org/calendar.ics",
	     "-read uses the configured URL");
  PASS([[store events] count] == 1, "-read loads the events");
  PASS([[store tasks] count] == 1, "-read loads the tasks");
  event = (Event *)[store elementWithUID:@"event1"];
  PASS_EQUAL([event summary], @"Server event", "the event is read from the server data");
  PASS([event duration] == 60, "the properties of the event are read");
  PASS([event store] == store, "the event belongs to the store");
  PASS_EQUAL([[store elementWithUID:@"task1"] summary], @"Server task", "the task is read");
  PASS(![store modified], "-read doesn't mark the store as modified");
  PASS([panels count] == 0, "no error is displayed");

  /* Reading again takes the modifications from the server into account */
  resetServer([CALENDAR stringByReplacingString:@"Server event" withString:@"Changed event"],
	      @"\"etag0\"");
  [store read];
  waitForOperations();
  PASS([[store events] count] == 1, "a second -read doesn't duplicate the events");
  PASS_EQUAL([[store elementWithUID:@"event1"] summary], @"Changed event",
	     "a second -read updates the events");

  /* BUG : -fillWithElements: only adds, elements removed on the server stay */
  resetServer(EMPTY_CALENDAR, @"\"etag0\"");
  [store read];
  waitForOperations();
  testHopeful = YES;
  PASS([[store events] count] == 0, "elements removed on the server disappear on -read");
  PASS([[store tasks] count] == 0, "tasks removed on the server disappear on -read");
  testHopeful = NO;

  /* Data that can't be parsed */
  store = newStore(@"garbage", NO);
  resetServer(@"this isn't a calendar", @"\"etag0\"");
  [store read];
  waitForOperations();
  PASS([[store events] count] == 0, "-read with invalid data loads nothing");
  PASS([store enabled] && [panels count] == 0, "invalid data isn't reported as a read error");

  /* Read errors disable the store */
  store = newStore(@"readError", NO);
  resetServer(CALENDAR, @"\"etag0\"");
  forceStatus(@"GET", 404);
  [store read];
  waitForOperations();
  PASS(![store enabled], "a read error disables the store");
  PASS([panels count] == 1, "a read error is displayed once");
  PASS([[[panels lastObject] objectForKey:@"title"] rangeOfString:@"readError"].length > 0,
       "the error contains the name of the store");
  PASS([[store events] count] == 0, "a read error loads nothing");

  /* A disabled store doesn't read, enabling it does */
  resetServer(CALENDAR, @"\"etag0\"");
  [store read];
  waitForOperations();
  PASS(requestCount(@"GET") == 0, "-read does nothing on a disabled store");
  [store setEnabled:YES];
  waitForOperations();
  PASS(requestCount(@"GET") == 1, "enabling a store reads it");
  PASS([[store events] count] == 1, "enabling a store loads the elements");
  [requests removeAllObjects];
  [store setDisplayed:NO];
  waitForOperations();
  PASS([requests count] == 0, "other configuration changes don't read the store");

  /* Read only stores keep the modifications in memory */
  store = newStore(@"readOnly", NO);
  resetServer(EMPTY_CALENDAR, @"\"etag0\"");
  task = AUTORELEASE([[Task alloc] initWithSummary:@"Local"]);
  [store add:task];
  waitForOperations();
  PASS([store contains:task], "-add: works on a read only store");
  PASS([store modified], "a read only store stays modified");
  PASS(requestCount(@"PUT") == 0, "a read only store sends nothing");
  [store write];
  waitForOperations();
  PASS(requestCount(@"PUT") == 0, "-write does nothing on a read only store");

  /* Writing */
  store = newStore(@"write", YES);
  resetServer(CALENDAR, @"\"etag0\"");
  [store read];
  waitForOperations();

  [store write];
  waitForOperations();
  PASS(requestCount(@"PUT") == 0, "-write does nothing on an unmodified store");

  event = AUTORELEASE([[Event alloc] initWithStartDate:[Date now] duration:30 title:@"Added"]);
  [store add:event];
  waitForOperations();
  PASS([store contains:event], "-add: adds the event to the store");
  PASS(requestCount(@"PUT") == 1, "-add: sends a PUT");
  PASS(lastPutContains(@"SUMMARY:Added"), "the PUT contains the new event");
  PASS(lastPutContains(@"SUMMARY:Server event") && lastPutContains(@"SUMMARY:Server task"),
       "the PUT contains the elements already read");
  PASS_EQUAL([lastRequest(@"PUT") objectForKey:@"If"], @"([\"etag0\"])",
	     "the PUT is protected by the ETag of the last GET");
  PASS(requestCount(@"PROPFIND") == 1, "a PUT is followed by a PROPFIND");
  PASS(![store modified], "a successful write resets the modified state");

  [event setSummary:@"Updated"];
  [store update:event];
  waitForOperations();
  PASS(requestCount(@"PUT") == 2, "-update: sends a PUT");
  PASS(lastPutContains(@"SUMMARY:Updated"), "the PUT contains the new summary");
  PASS(!lastPutContains(@"SUMMARY:Added"), "the PUT doesn't contain the old summary");
  PASS_EQUAL([lastRequest(@"PUT") objectForKey:@"If"], @"([\"etag1\"])",
	     "the PUT uses the ETag obtained by the PROPFIND");

  [store remove:event];
  waitForOperations();
  PASS(![store contains:event], "-remove: removes the event from the store");
  PASS(requestCount(@"PUT") == 3, "-remove: sends a PUT");
  PASS(!lastPutContains(@"SUMMARY:Updated"), "the PUT doesn't contain the removed event");
  PASS(![store modified], "the store isn't modified after the last write");

  /* Elements unknown to the calendar */
  event = AUTORELEASE([[Event alloc] initWithStartDate:[Date now] duration:30 title:@"Unknown"]);
  [store remove:event];
  [store update:event];
  waitForOperations();
  PASS(requestCount(@"PUT") == 3, "-remove: and -update: of an unknown element send nothing");
  PASS(![store modified], "-remove: and -update: of an unknown element change nothing");

  /* A new reader gets what was written */
  [store add:AUTORELEASE([[Task alloc] initWithSummary:@"Persisted"])];
  waitForOperations();
  {
    id <SharedStore> other = newStore(@"other", NO);
    NSEnumerator *enumerator;
    Task *current;
    BOOL found = NO;

    [other read];
    waitForOperations();
    enumerator = [[other tasks] objectEnumerator];
    while ((current = [enumerator nextObject]))
      if ([[current summary] isEqual:@"Persisted"])
	found = YES;
    PASS(found, "what is written can be read by another store");
  }

  /* A conflict rereads the calendar and keeps the store writable */
  store = newStore(@"conflict", YES);
  resetServer(CALENDAR, @"\"etag0\"");
  [store read];
  waitForOperations();
  [requests removeAllObjects];
  forceStatus(@"PUT", 412);
  [store add:AUTORELEASE([[Task alloc] initWithSummary:@"Conflict"])];
  waitForOperations();
  PASS([store writable], "a 412 keeps the store writable");
  PASS([panels count] == 1, "a 412 is displayed once");
  PASS(requestCount(@"GET") == 1, "a 412 rereads the calendar");
  PASS([store enabled], "a 412 keeps the store enabled");
  PASS(requestCount(@"PROPFIND") == 0, "a failed PUT isn't followed by a PROPFIND");

  /* Other write errors make the store read only */
  store = newStore(@"writeError", YES);
  resetServer(CALENDAR, @"\"etag0\"");
  [store read];
  waitForOperations();
  [requests removeAllObjects];
  forceStatus(@"PUT", 500);
  [store add:AUTORELEASE([[Task alloc] initWithSummary:@"Error"])];
  waitForOperations();
  PASS(![store writable], "a write error makes the store read only");
  PASS([panels count] == 1, "a write error is displayed once");
  PASS(requestCount(@"GET") == 1, "a write error rereads the calendar");
  PASS([store enabled], "a write error keeps the store enabled");

  /* Credentials */
  {
    ConfigManager *cm = AUTORELEASE([[ConfigManager alloc] initForKey:@"credentials"]);

    [cm setObject:@"user" forKey:ST_USERNAME];
    [cm setObject:@"secret" forKey:ST_PASSWORD];
    store = newStore(@"credentials", NO);
    resetServer(CALENDAR, @"\"etag0\"");
    [store read];
    waitForOperations();
    PASS_EQUAL([lastRequest(@"GET") objectForKey:@"url"],
	       @"mock://user:secret@example.org/calendar.ics",
	       "the configured credentials are used");
  }

  /* Periodic refresh */
  store = newStore(@"refresh", NO);
  resetServer(CALENDAR, @"\"etag0\"");
  [store setRefreshInterval:1];
  PASS([store refreshInterval] == 1, "-setRefreshInterval: works");
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.5]];
  waitForOperations();
  PASS(requestCount(@"GET") == 0, "no refresh while periodic refresh is disabled");
  [store setPeriodicRefresh:YES];
  PASS([store periodicRefresh], "-setPeriodicRefresh:YES works");
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.5]];
  waitForOperations();
  PASS(requestCount(@"GET") >= 1, "periodic refresh reads the store");
  [store setPeriodicRefresh:NO];
  PASS(![store periodicRefresh], "-setPeriodicRefresh:NO works");
  waitForOperations();
  [requests removeAllObjects];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.5]];
  waitForOperations();
  PASS(requestCount(@"GET") == 0, "disabling periodic refresh stops the timer");

  [ud removePersistentDomainForName:domain];
  [ud synchronize];
  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
