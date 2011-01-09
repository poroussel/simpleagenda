#import <Foundation/Foundation.h>
#import <GNUstepBase/GSXML.h>
#import <GNUstepBase/GSMime.h>
#import "WebDAVResource.h"

@implementation WebDAVResource
- (void)dealloc
{
  DESTROY(_user);
  DESTROY(_password);
  DESTROY(_lock);
  DESTROY(_lastModified);
  DESTROY(_data);
  DESTROY(_request);
  [super dealloc];
}

- (NSURL *)fixSchemeOfURL:(NSURL *)anUrl
{
  if ([[anUrl scheme] hasPrefix:@"webcal"])
    return [NSURL URLWithString:[[anUrl absoluteString] stringByReplacingString:@"webcal" withString:@"http"]];
  return anUrl;
}

- (id)initWithURL:(NSURL *)anUrl
{
  if ((self = [super init])) {
    _request = [[NSMutableURLRequest alloc] initWithURL:[self fixSchemeOfURL:anUrl]];
    _lock = [NSLock new];
    _user = [[[_request URL] user] retain];
    _password = [[[_request URL] password] retain];
    _data = [[NSMutableData alloc] initWithCapacity:8192];
  }
  return self;
}

- (id)initWithURL:(NSURL *)anUrl authFromURL:(NSURL *)parent
{
  if ((self = [self initWithURL:anUrl]) && [parent user]) {
      ASSIGN(_user, [parent user]);
      ASSIGN(_password, [parent password]);
  }
  return self;
}

- (BOOL)requestWithMethod:(NSString *)method body:(NSData *)body attributes:(NSDictionary *)attributes
{
  NSEnumerator *enumerator;
  NSString *key;
  NSURLConnection *connection;
  NSRunLoop *loop;
  NSDate *limit;

  [_lock lock];
  [_request setValue:method forHTTPHeaderField:GSHTTPPropertyMethodKey];
  if (attributes) {
    enumerator = [attributes keyEnumerator];
    while ((key = [enumerator nextObject]))
      [_request setValue:[attributes objectForKey:key] forHTTPHeaderField:key];
  }
  if (_etag && ([method isEqual:@"PUT"] || [method isEqual:@"DELETE"]))
    [_request setValue:[NSString stringWithFormat:@"([%@])", _etag] forHTTPHeaderField:@"If"];
  if (body)
    [_request setHTTPBody:body];
  NSDebugLog(@"%@ %@ (%@)", [[_request URL] absoluteString], method, [attributes description]);

  _done = NO;
  connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];
  if (!connection) {
    NSLog(@"Connection cannot be created for %@", [_request description]);
    [_lock unlock];
    return NO;
  }
  loop = [NSRunLoop currentRunLoop];
  while (_done == NO) {
    limit = [[NSDate alloc] initWithTimeIntervalSinceNow:1.0];
    [loop runMode:NSDefaultRunLoopMode beforeDate:limit];
    RELEASE(limit);
  }
  [connection release];

  if ([_data length])
    NSDebugLog(@"%@ =>\n%@", method, AUTORELEASE([[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding]));
  else
    NSDebugLog(@"%@ status %d", method, _httpStatus);
  if (_httpStatus < 200 || _httpStatus > 299) {
    NSLog(@"%s %@ : %d %@", __PRETTY_FUNCTION__, method, _httpStatus, _reason);
    [_lock unlock];
    return NO;
  }
  [_lock unlock];
  return YES;

}

/*
 * Status | Meaning
 *  200   | OK
 *  207   | MULTI STATUS
 *  304   | NOT MODIFIED
 *  401   | NO AUTH
 *  403   | WRONG PERM
 *  404   | NO FILE
 *  ...
 */
- (BOOL)readable
{
  [self get];
  if ((_httpStatus > 199 && _httpStatus < 300) || _httpStatus == 404)
    return YES;
  return NO;
}

/*
 * Status | Meaning
 *  201   | OK OVERWRITE
 *  204   | OK CREATE
 *  401   | NO AUTH
 *  403   | WRONG PERM
 *  ...
 */
- (BOOL)writableWithData:(NSData *)data
{
  return [self put:data attributes:nil];
}

- (int)httpStatus
{
  return _httpStatus;
}

- (NSData *)data
{
  return _data;
}

- (NSString *)reason
{
  return _reason;
}

- (NSURL *)url
{
  return [_request URL];
}

- (BOOL)get
{
  return [self requestWithMethod:@"GET" body:nil attributes:nil];
}

- (BOOL)put:(NSData *)data attributes:(NSDictionary *)attributes
{
  return [self requestWithMethod:@"PUT" body:data attributes:attributes];
}

- (BOOL)delete
{
  return [self requestWithMethod:@"DELETE" body:nil attributes:nil];
}

- (BOOL)propfind:(NSData *)data attributes:(NSDictionary *)attributes
{
  return [self requestWithMethod:@"PROPFIND" body:data attributes:attributes];
}

static NSString * const GETETAG = @"string(/multistatus/response/propstat/prop/getetag/text())";
static NSString * const GETLASTMODIFIED = @"string(/multistatus/response/propstat/prop/getlastmodified/text())";
- (void)updateAttributes;
{
  GSXMLParser *parser;
  GSXPathContext *xpc;
  GSXPathString *result;

  if ([self propfind:nil attributes:nil]) {
    parser = [GSXMLParser parserWithData:[self data]];
    if ([parser parse]) {
      xpc = [[GSXPathContext alloc] initWithDocument:[[parser document] strippedDocument]];
      result = (GSXPathString *)[xpc evaluateExpression:GETETAG];
      if (result)
	ASSIGN(_etag, [result stringValue]);
      result = (GSXPathString *)[xpc evaluateExpression:GETLASTMODIFIED];
      if (result)
	ASSIGN(_lastModified, [result stringValue]);
    }
  }
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
}
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
  NSURLCredential *cd;

  if (_user) {
    cd = [NSURLCredential credentialWithUser:_user password:_password persistence:NSURLCredentialPersistenceNone];
    [[challenge sender] useCredential:cd forAuthenticationChallenge:challenge];
  }
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [_data appendData:data];
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
  NSString *property;

  _httpStatus = [response statusCode];
  ASSIGNCOPY(_reason, [NSHTTPURLResponse localizedStringForStatusCode:_httpStatus]);
  [_data setLength:0];
  if ([[_request HTTPMethod] isEqual:@"GET"]) {
    property = [[response allHeaderFields] valueForKey:@"Last-Modified"];
    if (!_lastModified || (property && ![property isEqual:_lastModified])) {
      _dataChanged = YES;
      ASSIGN(_lastModified, property);
    }
    property = [[response allHeaderFields] valueForKey:@"ETag"];
    if (!_etag || (property && ![property isEqual:_etag])) {
      _dataChanged = YES;
      ASSIGN(_etag, property);
    }
  }
}
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
  return cachedResponse;
}
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)newRequest redirectResponse:(NSURLResponse *)response
{
  return newRequest;
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  _done = YES;
}
@end

@implementation NSURL(SimpleAgenda)
+ (BOOL)stringIsValidURL:(NSString *)string
{
  BOOL valid = NO;
  NSURL *url;

  NS_DURING
    {
      url = [NSURL URLWithString:string];
      valid = url ? YES : NO;
    }
  NS_HANDLER
    {
    }
  NS_ENDHANDLER
    return valid;
}
+ (NSURL *)URLWithString:(NSString *)string possiblyRelativeToURL:(NSURL *)base
{
  NSURL *url;

  if ([NSURL stringIsValidURL:string])
    url = [NSURL URLWithString:string];
  else
    url = [NSURL URLWithString:[[base absoluteString] stringByReplacingString:[base path] withString:string]];
  return url;
}
@end

@implementation GSXMLDocument(SimpleAgenda)
static GSXMLDocument *removeXSLT;
static const NSString *removeString = @"<?xml version='1.0' encoding='UTF-8'?> \
<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'> \
<xsl:output method='xml' encoding='UTF-8' /> \
<xsl:template match='/'> \
<xsl:copy> \
<xsl:apply-templates /> \
</xsl:copy> \
</xsl:template> \
<xsl:template match='*'> \
<xsl:element name='{local-name()}'> \
<xsl:apply-templates select='@* | node()' /> \
</xsl:element> \
</xsl:template> \
<xsl:template match='@*'> \
<xsl:attribute name='{local-name()}'><xsl:value-of select='.' /></xsl:attribute> \
</xsl:template> \
<xsl:template match='text() | processing-instruction() | comment()'> \
<xsl:copy /> \
</xsl:template> \
</xsl:stylesheet>";
- (GSXMLDocument *)strippedDocument
{
  if (removeXSLT == nil) {
    GSXMLParser *parser = [GSXMLParser parserWithData:[removeString dataUsingEncoding:NSUTF8StringEncoding]];
    if (![parser parse]) {
      NSLog(@"Error parsing xslt document");
      return nil;
    }
    removeXSLT = RETAIN([parser document]);
  }
  return [self xsltTransform:removeXSLT];
}
@end
