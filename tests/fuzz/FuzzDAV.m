/* -*- objc -*-
 *
 * libFuzzer harness for the WebDAV / GroupDAV / CalDAV client code.
 *
 * There is no network : every URL, whatever its scheme, is served by
 * MockHandle. The fuzz input is a list of canned HTTP responses, consumed
 * one per request, in this text format :
 *
 *   207 Multi-Status          <- status code and optional reason
 *   ETag: "abc"               <- optional headers (Location, ETag, Last-Modified...)
 *                             <- empty line
 *   <?xml ...>                <- body, raw bytes
 *   =====                     <- separator line before the next response
 *   200 OK
 *   ...
 *
 * When there's no response left, requests get a 599 status without body.
 * The same responses are replayed for each scenario :
 *   1. WebDAVResource : GET, PROPFIND/-updateAttributes, PUT, DELETE, redirections
 *   2. GroupDAVDialog -calendarURLFromRootOfServer:error: (CalDAV discovery)
 *   3. GroupDAVDialog -checkDirectories (collection listing)
 *   4. GroupDAVStore : read (PROPFIND + GET + iCal parsing), update, write, remove
 *
 * FUZZ_DAV_SCENARIOS=<bitmask> runs only some of them (1, 2, 4, 8 ; default 15).
 *
 * Any crash, sanitizer report or uncaught ObjC exception is a finding.
 */

#define _GNU_SOURCE
#include <string.h>
#include <stdlib.h>
#import <Foundation/Foundation.h>
#import "WebDAVResource.h"
#import "MemoryStore.h"
#import "Element.h"
#import "defines.h"

#define MAX_RESPONSES 64
#define MAX_REQUESTS 256

static NSArray *responses;
static NSUInteger cursor;
static NSUInteger requestCount;
static int scenarios = 15;

/* Methods declared in GroupDAVStore.m only */
@interface NSObject(FuzzDAVPrivate)
- (NSURL *)calendarURLFromRootOfServer:(NSURL *)originalURL error:(NSError **)error;
@end

/*
 * Mock HTTP server
 */
@interface MockHandle : NSURLHandle
{
  NSDictionary *_response;
}
@end
@implementation MockHandle
+ (BOOL)canInitWithURL:(NSURL *)url
{
  return YES;
}
+ (NSURLHandle *)cachedHandleForURL:(NSURL *)url
{
  return nil;
}
- (id)initWithURL:(NSURL *)url cached:(BOOL)cached
{
  return [super initWithURL:url cached:NO];
}
- (void)dealloc
{
  RELEASE(_response);
  [super dealloc];
}
- (BOOL)writeProperty:(id)value forKey:(NSString *)key
{
  return YES;
}
- (BOOL)writeData:(NSData *)data
{
  return YES;
}
- (NSData *)resourceData
{
  requestCount++;
  if (cursor < [responses count] && requestCount <= MAX_REQUESTS)
    ASSIGN(_response, [responses objectAtIndex:cursor++]);
  else
    ASSIGN(_response, [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:599]
						  forKey:NSHTTPPropertyStatusCodeKey]);
  return [_response objectForKey:@"body"];
}
- (id)propertyForKey:(NSString *)key
{
  if ([key isEqual:NSHTTPPropertyStatusCodeKey] || [key isEqual:NSHTTPPropertyStatusReasonKey])
    return [_response objectForKey:key];
  return [[_response objectForKey:@"headers"] objectForKey:key];
}
- (id)propertyForKeyIfAvailable:(NSString *)key
{
  return [self propertyForKey:key];
}
@end

/*
 * Input parsing
 */
static NSString *makeString(const uint8_t *bytes, size_t len)
{
  NSString *s = [[NSString alloc] initWithBytes:bytes length:len encoding:NSUTF8StringEncoding];

  if (s == nil)
    s = [[NSString alloc] initWithBytes:bytes length:len encoding:NSISOLatin1StringEncoding];
  return AUTORELEASE(s);
}

static size_t lineLength(const uint8_t *p, size_t len, size_t *next)
{
  const uint8_t *nl = memchr(p, '\n', len);
  size_t l = nl ? (size_t)(nl - p) : len;

  *next = nl ? l + 1 : len;
  if (l > 0 && p[l - 1] == '\r')
    l--;
  return l;
}

static NSDictionary *parseResponse(const uint8_t *p, size_t len)
{
  NSMutableDictionary *response = [NSMutableDictionary dictionary];
  NSMutableDictionary *headers = [NSMutableDictionary dictionary];
  size_t next, l, i;
  int status = 0;

  /* Status line */
  l = lineLength(p, len, &next);
  for (i = 0; i < l && i < 6 && p[i] >= '0' && p[i] <= '9'; i++)
    status = status * 10 + (p[i] - '0');
  while (i < l && p[i] == ' ')
    i++;
  [response setObject:[NSNumber numberWithInt:status] forKey:NSHTTPPropertyStatusCodeKey];
  if (i < l)
    [response setObject:makeString(p + i, l - i) forKey:NSHTTPPropertyStatusReasonKey];
  p += next;
  len -= next;

  /* Headers, up to an empty line */
  while (len > 0) {
    l = lineLength(p, len, &next);
    if (l == 0) {
      p += next;
      len -= next;
      break;
    }
    const uint8_t *colon = memchr(p, ':', l);
    if (colon) {
      size_t nlen = colon - p;
      size_t vstart = nlen + 1;
      while (vstart < l && p[vstart] == ' ')
	vstart++;
      [headers setObject:makeString(p + vstart, l - vstart) forKey:makeString(p, nlen)];
    }
    p += next;
    len -= next;
  }
  [response setObject:headers forKey:@"headers"];
  [response setObject:[NSData dataWithBytes:p length:len] forKey:@"body"];
  return response;
}

static NSArray *parseResponses(const uint8_t *data, size_t size)
{
  static const char sep[] = "\n=====\n";
  NSMutableArray *list = [NSMutableArray array];
  size_t start = 0;

  while ([list count] < MAX_RESPONSES) {
    const uint8_t *p = memmem(data + start, size - start, sep, sizeof(sep) - 1);
    size_t end = p ? (size_t)(p - data) : size;
    [list addObject:parseResponse(data + start, end - start)];
    if (!p)
      break;
    start = end + sizeof(sep) - 1;
  }
  return list;
}

static void replay(void)
{
  cursor = 0;
  requestCount = 0;
}

/*
 * Fake widgets for GroupDAVDialog outlets, no display needed
 */
@interface FakeField : NSObject
{
  NSString *_value;
}
@end
@implementation FakeField
- (void)dealloc
{
  RELEASE(_value);
  [super dealloc];
}
- (NSString *)stringValue
{
  return _value;
}
- (void)setStringValue:(NSString *)value
{
  ASSIGN(_value, value);
}
- (void)setEnabled:(BOOL)flag
{
}
@end

@interface FakePopUp : NSObject
{
  NSMutableArray *_items;
  NSInteger _selected;
}
@end
@implementation FakePopUp
- (id)init
{
  if ((self = [super init])) {
    _items = [NSMutableArray new];
    _selected = -1;
  }
  return self;
}
- (void)dealloc
{
  RELEASE(_items);
  [super dealloc];
}
- (void)removeAllItems
{
  [_items removeAllObjects];
  _selected = -1;
}
- (void)addItemWithTitle:(NSString *)title
{
  /* NSPopUpButton/NSMenu don't accept a nil title */
  if (title == nil)
    [NSException raise:NSInvalidArgumentException format:@"-addItemWithTitle: nil title"];
  [_items addObject:title];
  if (_selected < 0)
    _selected = 0;
}
- (NSInteger)numberOfItems
{
  return [_items count];
}
- (void)selectItemAtIndex:(NSInteger)index
{
  /* NSPopUpButton ignores out of range indexes */
  if (index >= 0 && index < (NSInteger)[_items count])
    _selected = index;
}
- (NSInteger)indexOfSelectedItem
{
  return _selected;
}
- (id)selectedItem
{
  return _selected >= 0 ? [_items objectAtIndex:_selected] : nil;
}
- (NSInteger)indexOfItem:(id)item
{
  return item ? (NSInteger)[_items indexOfObject:item] : -1;
}
- (NSString *)titleOfSelectedItem
{
  return [self selectedItem];
}
@end

/*
 * Scenarios
 */
static void fuzzResource(void)
{
  WebDAVResource *resource;

  replay();
  resource = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:@"mock://example.org/dav/calendar.ics"]
					username:@"user"
					password:@"p@ss:w/rd"];
  [resource get];
  [resource data];
  [resource reason];
  [[resource url] anonymousAbsoluteString];
  [resource updateAttributes];
  [resource put:[@"BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n" dataUsingEncoding:NSUTF8StringEncoding]
     attributes:[NSDictionary dictionaryWithObject:@"text/calendar" forKey:@"Content-Type"]];
  [resource delete];
  [resource readable];
  [resource release];
}

static id newDialog(void)
{
  id dialog = [[NSClassFromString(@"GroupDAVDialog") alloc] init];
  FakeField *username = AUTORELEASE([FakeField new]);
  FakeField *password = AUTORELEASE([FakeField new]);

  [username setStringValue:@"user"];
  [password setStringValue:@"p@ss:w/rd"];
  [dialog setValue:username forKey:@"usernameField"];
  [dialog setValue:password forKey:@"passwordField"];
  return dialog;
}

static void fuzzDiscovery(void)
{
  id dialog = newDialog();
  NSError *error = nil;
  NSURL *found;

  replay();
  found = [dialog calendarURLFromRootOfServer:[NSURL URLWithString:@"mock://example.org/"] error:&error];
  [found absoluteString];
  [error localizedDescription];
  [error localizedFailureReason];
  [dialog release];
}

static void fuzzCheckDirectories(void)
{
  id dialog = newDialog();
  FakeField *url = AUTORELEASE([FakeField new]);

  /* A path avoids the discovery, which shows an alert panel on errors */
  [url setStringValue:@"mock://example.org/dav/"];
  [dialog setValue:url forKey:@"url"];
  [dialog setValue:AUTORELEASE([FakePopUp new]) forKey:@"calendar"];
  [dialog setValue:AUTORELEASE([FakePopUp new]) forKey:@"task"];
  [dialog setValue:AUTORELEASE([FakeField new]) forKey:@"ok"];
  replay();
  [dialog performSelector:@selector(checkDirectories)];
  [dialog performSelector:@selector(calendar)];
  [dialog performSelector:@selector(task)];
  [dialog release];
}

static void fuzzStore(void)
{
  id <MemoryStore> store;
  NSMutableArray *elements;
  NSEnumerator *e;
  Element *elt;

  replay();
  store = [NSClassFromString(@"GroupDAVStore") storeNamed:@"FuzzDAVStore"];
  /* -read would use the StoreManager operation queue : stay synchronous */
  [(id)store performSelector:@selector(doRead)];
  elements = [NSMutableArray arrayWithArray:[store events]];
  [elements addObjectsFromArray:[store tasks]];
  e = [elements objectEnumerator];
  while ((elt = [e nextObject])) {
    [elt setSummary:@"Modified by the fuzzer"];
    /* The store isn't writable : -update: won't queue a -write */
    [store update:elt];
  }
  [(id)store performSelector:@selector(doWrite)];
  e = [elements objectEnumerator];
  while ((elt = [e nextObject]))
    [store remove:elt];
}

int LLVMFuzzerInitialize(int *argc, char ***argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSArray *schemes = [NSArray arrayWithObjects:@"mock", @"http", @"https", @"webcal", @"file", @"ftp", nil];
  NSEnumerator *e;
  NSString *scheme;
  const char *env = getenv("FUZZ_DAV_SCENARIOS");

  if (env)
    scenarios = atoi(env);
  [NSURLHandle registerURLHandleClass:[MockHandle class]];
  /* Never touch the network nor the filesystem */
  e = [schemes objectEnumerator];
  while ((scheme = [e nextObject])) {
    NSURL *url = [NSURL URLWithString:[scheme stringByAppendingString:@"://example.org/x"]];
    if ([NSURLHandle URLHandleClassForURL:url] != [MockHandle class]) {
      fprintf(stderr, "FuzzDAV : %s URLs aren't served by MockHandle\n", [scheme UTF8String]);
      abort();
    }
  }
  /* Store configuration, in the volatile registration domain : nothing is written */
  [[NSUserDefaults standardUserDefaults] registerDefaults:
    [NSDictionary dictionaryWithObject:
      [NSDictionary dictionaryWithObjectsAndKeys:
		      @"mock://example.org/dav/", ST_URL,
		      @"mock://example.org/dav/calendar/", ST_CALENDAR_URL,
		      @"mock://example.org/dav/tasks/", ST_TASK_URL,
		      @"user", ST_USERNAME,
		      @"p@ss:w/rd", ST_PASSWORD,
		      [NSNumber numberWithBool:NO], ST_RW,
		      nil]
				forKey:@"FuzzDAVStore"]];
  [pool release];
  return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  @try {
    responses = [parseResponses(data, size) retain];
    if (scenarios & 1)
      fuzzResource();
    if (scenarios & 2)
      fuzzDiscovery();
    if (scenarios & 4)
      fuzzCheckDirectories();
    if (scenarios & 8)
      fuzzStore();
  } @catch (NSException *ex) {
    NSLog(@"Uncaught exception %@ : %@\n%@", [ex name], [ex reason],
	  [[ex callStackSymbols] componentsJoinedByString:@"\n"]);
    abort();
  }
  DESTROY(responses);
  [pool release];
  return 0;
}
