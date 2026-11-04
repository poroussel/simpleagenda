/* -*- objc -*- */

#import "ObjectTesting.h"
#import "WebDAVResource.h"

/*
 * No network here : mock:// URLs are served by MockHandle. Each request
 * consumes a canned response and is recorded with its properties, its body
 * and its URL. Without any response left, the status is 599.
 */
static NSMutableArray *requests;
static NSMutableArray *responses;
static int liveHandles;

@interface MockHandle : NSURLHandle
{
  NSMutableDictionary *_request;
  NSDictionary *_response;
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
    liveHandles++;
    _request = [NSMutableDictionary new];
    [_request setObject:[url absoluteString] forKey:@"url"];
    [_request setObject:[NSNumber numberWithBool:cached] forKey:@"cached"];
  }
  return self;
}
- (void)dealloc
{
  liveHandles--;
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
  [requests addObject:_request];
  if ([responses count] > 0) {
    ASSIGN(_response, [responses objectAtIndex:0]);
    [responses removeObjectAtIndex:0];
  } else
    ASSIGN(_response, [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:599]
						  forKey:NSHTTPPropertyStatusCodeKey]);
  return [[_response objectForKey:@"body"] dataUsingEncoding:NSUTF8StringEncoding];
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

static void respond(int status, NSString *reason, NSString *body, NSDictionary *headers)
{
  NSMutableDictionary *response = [NSMutableDictionary dictionary];

  [response setObject:[NSNumber numberWithInt:status] forKey:NSHTTPPropertyStatusCodeKey];
  if (reason)
    [response setObject:reason forKey:NSHTTPPropertyStatusReasonKey];
  if (body)
    [response setObject:body forKey:@"body"];
  if (headers)
    [response addEntriesFromDictionary:headers];
  [responses addObject:response];
}

static void reset(void)
{
  [requests removeAllObjects];
  [responses removeAllObjects];
}

static NSDictionary *header(NSString *name, NSString *value)
{
  return [NSDictionary dictionaryWithObject:value forKey:name];
}

static NSDictionary *lastRequest(void)
{
  return [requests lastObject];
}

static id lastProperty(NSString *name)
{
  return [lastRequest() objectForKey:name];
}

static NSData *utf8(NSString *string)
{
  return [string dataUsingEncoding:NSUTF8StringEncoding];
}

static NSString *contentOf(WebDAVResource *dav)
{
  return AUTORELEASE([[NSString alloc] initWithData:[dav data] encoding:NSUTF8StringEncoding]);
}

/* The ETag known by the resource is only visible in the next PUT */
static id etagSentBy(WebDAVResource *dav)
{
  respond(204, nil, nil, nil);
  [dav put:[NSData data] attributes:nil];
  return lastProperty(@"If");
}

static NSString *multistatus(NSString *props)
{
  return [NSString stringWithFormat:@"<?xml version=\"1.0\"?><D:multistatus xmlns:D=\"DAV:\"><D:response><D:propstat><D:prop>%@</D:prop></D:propstat></D:response></D:multistatus>", props];
}

static GSXMLDocument *parseXML(NSString *string)
{
  GSXMLParser *parser = [GSXMLParser parserWithData:utf8(string)];

  return [parser parse] ? [parser document] : nil;
}

static NSString *xpathString(GSXMLDocument *document, NSString *expression)
{
  GSXPathContext *xpc = AUTORELEASE([[GSXPathContext alloc] initWithDocument:document]);

  return [(GSXPathString *)[xpc evaluateExpression:expression] stringValue];
}

int main ()
{
  NSString *baseURL = @"http://droopy.octets.fr/calendar/test";
  WebDAVResource *dav;
  NSURL *url;
  NSDictionary *attributes;
  int i;

  CREATE_AUTORELEASE_POOL(arp);

  test_alloc(@"WebDAVResource");

  dav = [[WebDAVResource alloc] initWithURL:nil
				   username:nil
				   password:nil];
  PASS(dav != nil, "-initWithURL with nil URL works");
  test_NSObject(@"WebDAVResource", [NSArray arrayWithObject:dav]);
  RELEASE(dav);

  url = [NSURL URLWithString:baseURL];
  PASS(url != nil && [[url absoluteString] isEqualToString:baseURL], "+URLWithString works");

  dav = [[WebDAVResource alloc] initWithURL:url
				   username:nil
				   password:nil];
  PASS(dav != nil, "-initWithURL with simple URL works");
  PASS([[[dav url] absoluteString] isEqualToString:baseURL], "-initWithURL with simple URL keeps URL unchanged");
  RELEASE(dav);

  dav = [[WebDAVResource alloc] initWithURL:url
				   username:@"user"
				   password:@"password"];
  PASS(dav != nil, "-initWithURL with user/password works");
  PASS([[[dav url] user] isEqualToString:@"user"] &&
       [[[dav url] password] isEqualToString:@"password"], "-initWithURL with user/password keeps user/password");
  RELEASE(dav);

  dav = [[WebDAVResource alloc] initWithURL:url
				   username:@"p.o.roussel@free.fr"
				   password:@"$p@ssword"];
  PASS(dav != nil, "-initWithURL with user/password needing %% escaping works");
  PASS([[[dav url] absoluteString] isEqualToString:@"http://p.o.roussel%40free.fr:$p%40ssword@droopy.octets.fr/calendar/test"], "-initWithURL URL is correctly escaped");
  PASS([[[dav url] user] isEqualToString:@"p.o.roussel@free.fr"] &&
       [[[dav url] password] isEqualToString:@"$p@ssword"], "-initWithURL user/password encoding works");
  PASS([[[dav url] anonymousAbsoluteString] isEqualToString:@"http://xxx:yyy@droopy.octets.fr/calendar/test"], "-anonymousAbsoluteString works")
  RELEASE(dav);

  /* Credentials */
  dav = [[WebDAVResource alloc] initWithURL:url username:@"a:b/c#d?e f" password:@"p:w/d#?% \303\251"];
  PASS_EQUAL([[dav url] user], @"a:b/c#d?e f", "special characters in the user name are escaped");
  PASS_EQUAL([[dav url] password], @"p:w/d#?% \303\251", "special characters in the password are escaped");
  PASS_EQUAL([[dav url] host], @"droopy.octets.fr", "escaped credentials don't change the host");
  PASS_EQUAL([[dav url] path], @"/calendar/test", "escaped credentials don't change the path");
  RELEASE(dav);

  dav = [[WebDAVResource alloc] initWithURL:url username:@"user" password:nil];
  PASS_EQUAL([[dav url] absoluteString], baseURL, "a user name without password isn't added to the URL");
  RELEASE(dav);

  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:@"password"];
  PASS_EQUAL([[dav url] absoluteString], baseURL, "a password without user name isn't added to the URL");
  RELEASE(dav);

  dav = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:@"http://me:secret@example.org/"]
				   username:@"user"
				   password:@"password"];
  PASS_EQUAL([[dav url] user], @"me", "credentials in the URL have priority");
  PASS_EQUAL([[dav url] password], @"secret", "a password in the URL has priority");
  RELEASE(dav);

  /* BUG : iCalStoreDialog saves empty strings when no credentials are given */
  testHopeful = YES;
  dav = [[WebDAVResource alloc] initWithURL:url username:@"" password:@""];
  PASS_EQUAL([[dav url] absoluteString], baseURL, "empty credentials aren't added to the URL");
  RELEASE(dav);

  /* BUG : -setURL: replaces all the occurrences of the scheme in the URL */
  dav = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:@"http://example.org/?next=http://other.org/"]
				   username:@"user"
				   password:@"password"];
  PASS_EQUAL([[dav url] absoluteString], @"http://user:password@example.org/?next=http://other.org/",
	     "credentials are only added to the host of the URL");
  RELEASE(dav);
  testHopeful = NO;

  /* webcal URLs */
  dav = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:@"webcal://example.org/cal.ics"]
				   username:nil
				   password:nil];
  PASS_EQUAL([[dav url] absoluteString], @"http://example.org/cal.ics",
	     "webcal URLs are converted to http");
  RELEASE(dav);

  dav = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:@"webcals://example.org/cal.ics"]
				   username:nil
				   password:nil];
  PASS_EQUAL([[dav url] absoluteString], @"https://example.org/cal.ics",
	     "webcals URLs are converted to https");
  RELEASE(dav);

  dav = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:@"webcal://example.org/cal.ics"]
				   username:@"user"
				   password:@"password"];
  PASS_EQUAL([[dav url] absoluteString], @"http://user:password@example.org/cal.ics",
	     "credentials are added to converted webcal URLs");
  RELEASE(dav);

  /* BUG : -setURL: replaces all the occurrences of webcal in the URL */
  testHopeful = YES;
  dav = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:@"webcal://example.org/webcal/cal.ics"]
				   username:nil
				   password:nil];
  PASS_EQUAL([[dav url] absoluteString], @"http://example.org/webcal/cal.ics",
	     "webcal is only replaced in the scheme of the URL");
  RELEASE(dav);
  testHopeful = NO;

  /* NSURL helpers */
  PASS_EQUAL([url anonymousAbsoluteString], baseURL,
	     "-anonymousAbsoluteString doesn't modify a URL without credentials");
  /* BUG : the user name is only hidden if there's also a password */
  testHopeful = YES;
  PASS([[[NSURL URLWithString:@"http://user@example.org/"] anonymousAbsoluteString]
	 rangeOfString:@"user"].length == 0,
       "-anonymousAbsoluteString hides a user name without password");
  testHopeful = NO;
  PASS_EQUAL([[NSURL URLWithString:@"http://other/path" possiblyRelativeToURL:url] absoluteString],
	     @"http://other/path", "+URLWithString:possiblyRelativeToURL: keeps absolute URLs");
  PASS([[NSURL URLWithString:@"http://other/path" possiblyRelativeToURL:url] baseURL] == nil,
       "+URLWithString:possiblyRelativeToURL: doesn't use the base for absolute URLs");
  PASS_EQUAL([[NSURL URLWithString:@"http://other/path" possiblyRelativeToURL:nil] absoluteString],
	     @"http://other/path", "+URLWithString:possiblyRelativeToURL: works without a base");
  PASS_EQUAL([[NSURL URLWithString:@"/other" possiblyRelativeToURL:url] absoluteString],
	     @"http://droopy.octets.fr/other",
	     "+URLWithString:possiblyRelativeToURL: resolves absolute paths");
  PASS_EQUAL([[NSURL URLWithString:@"other" possiblyRelativeToURL:url] absoluteString],
	     @"http://droopy.octets.fr/calendar/other",
	     "+URLWithString:possiblyRelativeToURL: resolves relative paths");

  /* -strippedDocument */
  {
    GSXMLDocument *doc = parseXML(@"<?xml version=\"1.0\"?><D:a xmlns:D=\"DAV:\" xmlns:E=\"E:\" D:attr=\"value\" plain=\"plain value\">"
				  @"<D:b>text b</D:b><E:c><D:d>text d</D:d></E:c><!--comment--><e xmlns=\"default:\">text e</e></D:a>");
    GSXMLDocument *stripped = [doc strippedDocument];

    PASS(stripped != nil, "-strippedDocument returns a document");
    PASS_EQUAL(xpathString(doc, @"string(/a/b/text())"), @"",
	       "the elements of the original document have namespaces");
    PASS_EQUAL(xpathString(stripped, @"string(/a/b/text())"), @"text b",
	       "-strippedDocument removes the namespace prefixes");
    PASS_EQUAL(xpathString(stripped, @"string(/a/c/d/text())"), @"text d",
	       "-strippedDocument removes all the namespaces of the nested elements");
    PASS_EQUAL(xpathString(stripped, @"string(/a/e/text())"), @"text e",
	       "-strippedDocument removes the default namespaces");
    PASS_EQUAL(xpathString(stripped, @"string(/a/@attr)"), @"value",
	       "-strippedDocument removes the namespaces of the attributes");
    PASS_EQUAL(xpathString(stripped, @"string(/a/@plain)"), @"plain value",
	       "-strippedDocument keeps the other attributes");
    PASS_EQUAL(xpathString(stripped, @"string(/a/comment())"), @"comment",
	       "-strippedDocument keeps the comments");
    PASS_EQUAL(xpathString([parseXML(@"<x:y xmlns:x=\"x:\">again</x:y>") strippedDocument], @"string(/y/text())"),
	       @"again", "-strippedDocument works more than once");
  }

  /* From here, requests are sent to the mock */
  requests = [NSMutableArray new];
  responses = [NSMutableArray new];

  /* Without a handle class for the URL, requests fail without crashing */
  dav = [[WebDAVResource alloc] initWithURL:nil username:nil password:nil];
  PASS(![dav get], "-get with a nil URL returns NO");
  PASS([dav httpStatus] == 0 && [dav data] == nil, "-get with a nil URL gives no status and no data");
  RELEASE(dav);
  dav = [[WebDAVResource alloc] initWithURL:[NSURL URLWithString:@"mock://example.org/"] username:nil password:nil];
  PASS(![dav get], "-get with an unknown scheme returns NO");
  RELEASE(dav);

  [NSURLHandle registerURLHandleClass:[MockHandle class]];
  url = [NSURL URLWithString:@"mock://example.org/cal"];

  /* Initial state */
  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:nil];
  PASS([dav httpStatus] == 0, "-httpStatus is 0 before the first request");
  PASS([dav data] == nil, "-data is nil before the first request");
  PASS([dav reason] == nil, "-reason is nil before the first request");
  PASS([requests count] == 0, "creating a resource sends nothing");

  /* GET */
  respond(200, @"OK", @"content", nil);
  PASS([dav get], "-get returns YES on a 200");
  PASS([requests count] == 1, "-get sends one request");
  PASS_EQUAL(lastProperty(@"method"), @"GET", "-get sends a GET");
  PASS_EQUAL(lastProperty(@"url"), @"mock://example.org/cal", "-get uses the URL of the resource");
  PASS(![lastProperty(@"cached") boolValue], "requests don't use the cached handles");
  PASS(lastProperty(@"body") == nil, "-get sends no body");
  PASS([dav httpStatus] == 200, "-httpStatus returns the status");
  PASS_EQUAL([dav reason], @"OK", "-reason returns the reason");
  PASS_EQUAL(contentOf(dav), @"content", "-data returns the content");

  respond(404, @"Not found", @"error page", nil);
  PASS(![dav get], "-get returns NO on a 404");
  PASS([dav httpStatus] == 404, "-httpStatus returns the error");
  PASS_EQUAL([dav reason], @"Not found", "-reason returns the error reason");
  PASS([dav data] == nil, "-data is nil after an error");

  respond(200, nil, nil, nil);
  PASS([dav get], "a success without any content returns YES");
  PASS([dav data] == nil, "-data is nil without any content");
  PASS([dav reason] == nil, "-reason is reset if the server doesn't send one");

  respond(199, nil, nil, nil);
  PASS(![dav get], "199 is an error");
  respond(200, nil, @"", nil);
  PASS([dav get], "200 is a success");
  respond(299, nil, @"", nil);
  PASS([dav get], "299 is a success");
  respond(300, nil, nil, nil);
  PASS(![dav get], "300 is an error");
  respond(0, nil, nil, nil);
  PASS(![dav get], "a request without status is an error");
  RELEASE(dav);

  /* -readable */
  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:nil];
  respond(199, nil, nil, nil);
  PASS(![dav readable], "-readable is NO on a 199");
  respond(200, nil, @"", nil);
  PASS([dav readable], "-readable is YES on a 200");
  PASS_EQUAL(lastProperty(@"method"), @"GET", "-readable sends a GET");
  respond(299, nil, @"", nil);
  PASS([dav readable], "-readable is YES on a 299");
  respond(300, nil, nil, nil);
  PASS(![dav readable], "-readable is NO on a 300");
  respond(404, nil, nil, nil);
  PASS([dav readable], "-readable is YES on a 404 : the resource can be created");
  respond(401, nil, nil, nil);
  PASS(![dav readable], "-readable is NO on a 401");
  respond(403, nil, nil, nil);
  PASS(![dav readable], "-readable is NO on a 403");
  RELEASE(dav);

  /* PUT */
  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:nil];
  respond(201, @"Created", @"answer", nil);
  attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			       @"text/calendar", @"Content-Type", @"value", @"X-Other", nil];
  PASS([dav put:utf8(@"body") attributes:attributes], "-put:attributes: returns YES on a 201");
  PASS_EQUAL(lastProperty(@"method"), @"PUT", "-put:attributes: sends a PUT");
  PASS_EQUAL(lastProperty(@"body"), @"body", "-put:attributes: sends the data");
  PASS_EQUAL(lastProperty(@"Content-Type"), @"text/calendar", "-put:attributes: sends the attributes");
  PASS_EQUAL(lastProperty(@"X-Other"), @"value", "-put:attributes: sends all the attributes");
  PASS(lastProperty(@"If") == nil, "no If header without a known ETag");
  PASS_EQUAL(contentOf(dav), @"answer", "-data returns the answer of a PUT");
  respond(403, nil, nil, nil);
  PASS(![dav put:utf8(@"body") attributes:nil], "-put:attributes: returns NO on a 403");

  /* -writableWithData: */
  respond(204, nil, nil, nil);
  PASS([dav writableWithData:utf8(@"data")], "-writableWithData: returns YES on a 204");
  PASS_EQUAL(lastProperty(@"method"), @"PUT", "-writableWithData: sends a PUT");
  PASS_EQUAL(lastProperty(@"body"), @"data", "-writableWithData: sends the data");
  respond(201, nil, nil, nil);
  PASS([dav writableWithData:[NSData data]], "-writableWithData: returns YES on a 201");
  respond(401, nil, nil, nil);
  PASS(![dav writableWithData:[NSData data]], "-writableWithData: returns NO on a 401");
  respond(403, nil, nil, nil);
  PASS(![dav writableWithData:[NSData data]], "-writableWithData: returns NO on a 403");

  /* DELETE */
  respond(204, nil, nil, nil);
  PASS([dav delete], "-delete returns YES on a 204");
  PASS_EQUAL(lastProperty(@"method"), @"DELETE", "-delete sends a DELETE");
  PASS(lastProperty(@"body") == nil, "-delete sends no body");
  respond(404, nil, nil, nil);
  PASS(![dav delete], "-delete returns NO on a 404");

  /* PROPFIND */
  respond(207, nil, @"<xml/>", nil);
  PASS([dav propfind:utf8(@"query") attributes:header(@"Depth", @"1")],
       "-propfind:attributes: returns YES on a 207");
  PASS_EQUAL(lastProperty(@"method"), @"PROPFIND", "-propfind:attributes: sends a PROPFIND");
  PASS_EQUAL(lastProperty(@"body"), @"query", "-propfind:attributes: sends the data");
  PASS_EQUAL(lastProperty(@"Depth"), @"1", "-propfind:attributes: sends the attributes");
  PASS_EQUAL(contentOf(dav), @"<xml/>", "-data returns the answer of a PROPFIND");
  respond(403, nil, nil, nil);
  PASS(![dav propfind:nil attributes:nil], "-propfind:attributes: returns NO on a 403");
  RELEASE(dav);

  /* ETags protect from overwriting other modifications */
  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:nil];
  respond(200, nil, @"", header(@"ETag", @"\"tag1\""));
  [dav get];
  PASS(lastProperty(@"If") == nil, "no If header on a first GET");
  PASS_EQUAL(etagSentBy(dav), @"([\"tag1\"])", "the ETag of the last GET is sent with a PUT");
  respond(204, nil, nil, nil);
  [dav delete];
  PASS_EQUAL(lastProperty(@"If"), @"([\"tag1\"])", "the ETag of the last GET is sent with a DELETE");
  respond(200, nil, @"", nil);
  [dav get];
  PASS(lastProperty(@"If") == nil, "the ETag isn't sent with a GET");
  PASS_EQUAL(etagSentBy(dav), @"([\"tag1\"])", "a GET without an ETag keeps the known one");
  respond(207, nil, @"<xml/>", nil);
  [dav propfind:nil attributes:nil];
  PASS(lastProperty(@"If") == nil, "the ETag isn't sent with a PROPFIND");

  respond(200, nil, @"", header(@"ETag", @"\"tag2\""));
  [dav get];
  PASS_EQUAL(etagSentBy(dav), @"([\"tag2\"])", "a new ETag replaces the old one");

  respond(204, nil, nil, header(@"ETag", @"\"ignored\""));
  [dav put:[NSData data] attributes:nil];
  respond(207, nil, @"<xml/>", header(@"ETag", @"\"ignored\""));
  [dav propfind:nil attributes:nil];
  respond(204, nil, nil, header(@"ETag", @"\"ignored\""));
  [dav delete];
  PASS_EQUAL(etagSentBy(dav), @"([\"tag2\"])", "an ETag is only read from a GET");

  respond(404, nil, nil, header(@"ETag", @"\"ignored\""));
  [dav get];
  PASS_EQUAL(etagSentBy(dav), @"([\"tag2\"])", "an ETag isn't read from a failed GET");
  RELEASE(dav);

  /* Last-Modified has no getter */
  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:nil];
  respond(200, nil, @"", header(@"Last-Modified", @"monday"));
  [dav get];
  PASS_EQUAL([dav valueForKey:@"lastModified"], @"monday", "Last-Modified is read from a GET");
  respond(200, nil, @"", header(@"Last-Modified", @"tuesday"));
  [dav get];
  PASS_EQUAL([dav valueForKey:@"lastModified"], @"tuesday", "a new Last-Modified replaces the old one");
  respond(200, nil, @"", nil);
  [dav get];
  PASS_EQUAL([dav valueForKey:@"lastModified"], @"tuesday", "a GET without Last-Modified keeps the old one");
  respond(204, nil, nil, header(@"Last-Modified", @"ignored"));
  [dav put:[NSData data] attributes:nil];
  PASS_EQUAL([dav valueForKey:@"lastModified"], @"tuesday", "Last-Modified isn't read from a PUT");
  RELEASE(dav);

  /* -updateAttributes reads the attributes from a PROPFIND */
  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:nil];
  respond(200, nil, @"", header(@"ETag", @"\"old\""));
  [dav get];
  reset();
  respond(207, nil, multistatus(@"<D:getetag>\"tag3\"</D:getetag><D:getlastmodified>today</D:getlastmodified>"), nil);
  [dav updateAttributes];
  PASS_EQUAL(lastProperty(@"method"), @"PROPFIND", "-updateAttributes sends a PROPFIND");
  PASS(lastProperty(@"body") == nil, "-updateAttributes sends no body");
  PASS(lastProperty(@"If") == nil, "-updateAttributes sends no If header");
  PASS_EQUAL([dav valueForKey:@"lastModified"], @"today", "-updateAttributes updates Last-Modified");
  PASS_EQUAL(etagSentBy(dav), @"([\"tag3\"])", "-updateAttributes updates the ETag");

  respond(207, nil, @"<multistatus xmlns=\"DAV:\"><response><propstat><prop><getetag>\"tag4\"</getetag></prop></propstat></response></multistatus>", nil);
  [dav updateAttributes];
  PASS_EQUAL(etagSentBy(dav), @"([\"tag4\"])", "-updateAttributes works with a default namespace");

  respond(500, nil, multistatus(@"<D:getetag>\"ignored\"</D:getetag>"), nil);
  [dav updateAttributes];
  PASS_EQUAL(etagSentBy(dav), @"([\"tag4\"])", "-updateAttributes keeps the ETag on an error");

  respond(207, nil, @"this isn't xml", nil);
  PASS_RUNS([dav updateAttributes], "-updateAttributes handles invalid XML");
  PASS_EQUAL(etagSentBy(dav), @"([\"tag4\"])", "-updateAttributes keeps the ETag on invalid XML");

  /* BUG : string() always gives a result, so a missing ETag erases the known one */
  testHopeful = YES;
  respond(207, nil, multistatus(@"<D:getlastmodified>later</D:getlastmodified>"), nil);
  [dav updateAttributes];
  PASS_EQUAL(etagSentBy(dav), @"([\"tag4\"])", "-updateAttributes keeps the ETag if the answer has none");
  testHopeful = NO;
  RELEASE(dav);

  /* Redirections */
  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:nil];
  reset();
  respond(301, nil, nil, header(@"Location", @"mock://example.org/moved"));
  respond(200, @"OK", @"moved content", nil);
  PASS([dav get], "-get follows a 301");
  PASS([requests count] == 2, "a redirection sends a second request");
  PASS_EQUAL(lastProperty(@"url"), @"mock://example.org/moved", "the second request uses the new location");
  PASS_EQUAL([[dav url] absoluteString], @"mock://example.org/moved", "-url returns the new location");
  PASS_EQUAL(contentOf(dav), @"moved content", "-data comes from the new location");
  PASS([dav httpStatus] == 200, "-httpStatus comes from the new location");

  respond(200, nil, @"", nil);
  [dav get];
  PASS_EQUAL(lastProperty(@"url"), @"mock://example.org/moved", "the new location is kept for the next requests");

  respond(302, nil, nil, header(@"Location", @"mock://example.org/moved2"));
  respond(200, nil, @"", nil);
  PASS([dav get] && [[[dav url] absoluteString] isEqual:@"mock://example.org/moved2"], "-get follows a 302");

  respond(0, nil, nil, header(@"Location", @"mock://example.org/moved3"));
  respond(200, nil, @"", nil);
  PASS([dav get] && [[[dav url] absoluteString] isEqual:@"mock://example.org/moved3"],
       "-get follows a location without a status");

  respond(301, nil, nil, header(@"Location", @"mock://example.org/moved4"));
  respond(301, nil, nil, header(@"Location", @"mock://example.org/moved5"));
  respond(200, nil, @"", nil);
  PASS([dav get] && [[[dav url] absoluteString] isEqual:@"mock://example.org/moved5"],
       "-get follows multiple redirections");

  respond(301, nil, nil, nil);
  PASS(![dav get], "a 301 without a location is an error");
  PASS([dav httpStatus] == 301, "-httpStatus returns the 301");
  respond(303, nil, nil, header(@"Location", @"mock://example.org/other"));
  PASS(![dav get], "only 301 and 302 are followed");
  PASS_EQUAL([[dav url] absoluteString], @"mock://example.org/moved5", "a 303 doesn't change the URL");
  respond(404, nil, nil, header(@"Location", @"mock://example.org/other"));
  PASS(![dav get], "a location is ignored on an error");
  RELEASE(dav);

  /* Redirections send the same request again */
  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:nil];
  respond(200, nil, @"", header(@"ETag", @"\"tag\""));
  [dav get];
  respond(301, nil, nil, header(@"Location", @"mock://example.org/moved"));
  respond(204, nil, nil, nil);
  [requests removeAllObjects];
  PASS([dav put:utf8(@"body") attributes:header(@"Content-Type", @"text/calendar")], "-put:attributes: follows a redirection");
  PASS([requests count] == 2, "the PUT is sent twice");
  PASS_EQUAL(lastProperty(@"method"), @"PUT", "the method is kept after a redirection");
  PASS_EQUAL(lastProperty(@"body"), @"body", "the body is kept after a redirection");
  PASS_EQUAL(lastProperty(@"Content-Type"), @"text/calendar", "the attributes are kept after a redirection");
  PASS_EQUAL(lastProperty(@"If"), @"([\"tag\"])", "the ETag is kept after a redirection");
  RELEASE(dav);

  /* Credentials */
  dav = [[WebDAVResource alloc] initWithURL:url username:@"user" password:@"password"];
  reset();
  respond(200, nil, @"", nil);
  [dav get];
  PASS_EQUAL(lastProperty(@"url"), @"mock://user:password@example.org/cal", "requests contain the credentials");
  respond(301, nil, nil, header(@"Location", @"mock://example.org/moved"));
  respond(200, nil, @"", nil);
  [dav get];
  PASS_EQUAL(lastProperty(@"url"), @"mock://user:password@example.org/moved",
	     "credentials are added to the new location");
  respond(301, nil, nil, header(@"Location", @"mock://other:secret@example.org/moved2"));
  respond(200, nil, @"", nil);
  [dav get];
  PASS_EQUAL(lastProperty(@"url"), @"mock://other:secret@example.org/moved2",
	     "credentials in the new location have priority");
  RELEASE(dav);

  /* BUG : there's no limit to the number of redirections */
  dav = [[WebDAVResource alloc] initWithURL:url username:nil password:nil];
  reset();
  for (i = 0; i < 100; i++)
    respond(302, nil, nil, header(@"Location", @"mock://example.org/cal"));
  respond(200, nil, @"", nil);
  testHopeful = YES;
  [dav get];
  PASS([requests count] < 100, "a redirection loop is stopped");
  testHopeful = NO;
  RELEASE(dav);

  /* The handles aren't kept, whatever the path */
  PASS(liveHandles == 0, "all the handles are released");

  /* File URLs have no HTTP status */
  {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"WebDAVTest-%d", [[NSProcessInfo processInfo] processIdentifier]]];

    [utf8(@"file content") writeToFile:path atomically:NO];
    dav = [[WebDAVResource alloc] initWithURL:[NSURL fileURLWithPath:path] username:nil password:nil];
    PASS([dav get], "-get on an existing file is a success");
    PASS([dav httpStatus] == 200, "the status of an existing file is 200");
    PASS_EQUAL(contentOf(dav), @"file content", "-data returns the content of the file");
    PASS([dav readable], "-readable is YES on an existing file");
    RELEASE(dav);

    [fm removeFileAtPath:path handler:nil];
    dav = [[WebDAVResource alloc] initWithURL:[NSURL fileURLWithPath:path] username:nil password:nil];
    PASS(![dav get], "-get on a missing file is an error");
    PASS([dav httpStatus] == 199, "the status of a missing file is 199");
    PASS([dav data] == nil, "-data is nil for a missing file");
    PASS(![dav readable], "-readable is NO on a missing file");
    RELEASE(dav);
  }

  [requests release];
  [responses release];

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
