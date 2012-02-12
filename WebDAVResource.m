#import <GNUstepBase/GSXML.h>
#import <GNUstepBase/GSMime.h>
#import "NSString+SimpleAgenda.h"
#import "WebDAVResource.h"

@implementation WebDAVResource
- (void)dealloc
{
  [_user release];
  [_password release];
  [_url release];
  [_lastModified release];
  [_data release];
  [_reason release];
  [_etag release];
  [super dealloc];
}

- (void)setURL:(NSURL *)anURL
{
  if ([[anURL scheme] hasPrefix:@"webcal"])
    ASSIGN(_url, [NSURL URLWithString:[[anURL absoluteString] stringByReplacingString:@"webcal" withString:@"http"]]);
  else
    ASSIGN(_url, anURL);
  _handleClass = [NSURLHandle URLHandleClassForURL:_url];
  if ([_url user])
    ASSIGN(_user, [_url user]);
  if ([_url password])
    ASSIGN(_password, [_url password]);
}

- (id)initWithURL:(NSURL *)anUrl
{
  if ((self = [super init]))
    [self setURL:anUrl];
  return self;
}

- (id)initWithURL:(NSURL *)anUrl authFromURL:(NSURL *)parent
{
  self = [self initWithURL:anUrl];
  if (self && [parent user]) {
      ASSIGN(_user, [parent user]);
      ASSIGN(_password, [parent password]);
  }
  return self;
}

/* FIXME : ugly hack to work around NSURLHandle shortcomings */
- (NSString *)basicAuth
{
  NSMutableString *authorisation;
  NSString *toEncode;

  authorisation = [NSMutableString stringWithCapacity: 64];
  if ([_password length] > 0)
    toEncode = [NSString stringWithFormat: @"%@:%@", _user, _password];
  else
    toEncode = [NSString stringWithFormat: @"%@", _user];
  [authorisation appendFormat: @"Basic %@", [GSMimeDocument encodeBase64String: toEncode]];
  return authorisation;
}

- (BOOL)requestWithMethod:(NSString *)method body:(NSData *)body attributes:(NSDictionary *)attributes
{
  NSEnumerator *keys;
  NSString *key;
  NSData *data;
  NSString *property;
  NSURLHandle *handle;

 restart:
  handle = [[_handleClass alloc] initWithURL:_url cached:NO];
  [handle writeProperty:method forKey:GSHTTPPropertyMethodKey];
  if (attributes) {
    keys = [attributes keyEnumerator];
    while ((key = [keys nextObject]))
      [handle writeProperty:[attributes objectForKey:key] forKey:key];
  }
  if (_user && ![_url user])
    [handle writeProperty:[self basicAuth] forKey:@"Authorization"];
  if (_etag && ([method isEqual:@"PUT"] || [method isEqual:@"DELETE"]))
    [handle writeProperty:[NSString stringWithFormat:@"([%@])", _etag] forKey:@"If"];
  if (body)
    [handle writeData:body];
  if (attributes)
    NSDebugMLLog(@"WebDAVResource", @"%@ %@ (%@)", method, [_url anonymousAbsoluteString], [attributes description]);
  else
    NSDebugMLLog(@"WebDAVResource", @"%@ %@", method, [_url anonymousAbsoluteString]);
  DESTROY(_data);
  data = [handle resourceData];
  /* FIXME : this is more than ugly */
  if ([_url isFileURL])
    _httpStatus = data ? 200 : 199;
  else
    _httpStatus = [[handle propertyForKeyIfAvailable:NSHTTPPropertyStatusCodeKey] intValue];

  /* FIXME : why do we have to check for httpStatus == 0 */
  if ((_httpStatus == 0 ||_httpStatus == 301 || _httpStatus == 302) && [handle propertyForKey:@"Location"] != nil) {
    NSDebugMLLog(@"WebDAVResource", @"Redirection to %@", [handle propertyForKey:@"Location"]);
    [self setURL:[NSURL URLWithString:[handle propertyForKey:@"Location"]]];
    goto restart;
  }

  NSDebugMLLog(@"WebDAVResource", @"%@ status %d", method, _httpStatus);
  property = [handle propertyForKeyIfAvailable:NSHTTPPropertyStatusReasonKey];
  if (property)
    ASSIGN(_reason, property);
  else
    DESTROY(_reason);
  if (_httpStatus < 200 || _httpStatus > 299) {
    if (_reason)
      NSLog(@"%s %@ : %d %@", __PRETTY_FUNCTION__, method, _httpStatus, _reason);
    else
      NSLog(@"%s %@ : %d", __PRETTY_FUNCTION__, method, _httpStatus);
    [handle release];
    return NO;
  }

  if (data)
    ASSIGN(_data, data);
  if ([method isEqual:@"GET"]) {
    property = [handle propertyForKeyIfAvailable:@"Last-Modified"];
    if (!_lastModified || (property && ![property isEqual:_lastModified])) {
      _dataChanged = YES;
      ASSIGN(_lastModified, property);
    }
    property = [handle propertyForKeyIfAvailable:@"ETag"];
    if (!_etag || (property && ![property isEqual:_etag])) {
      _dataChanged = YES;
      ASSIGN(_etag, property);
    }
  }
  [handle release];
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
  return _url;
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
      [xpc release];
    }
  }
}
@end

@implementation NSURL(SimpleAgenda)
+ (NSURL *)URLWithString:(NSString *)string possiblyRelativeToURL:(NSURL *)base
{
  if ([string isValidURL])
    return [NSURL URLWithString:string];
  return [NSURL URLWithString:string relativeToURL:base];
}
- (NSString *)anonymousAbsoluteString
{
  NSString *as = [self absoluteString];

  if (![self user] && ![self password])
    return as;
  return [as stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@:%@@", [self user], [self password]]
				       withString:@""];
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
    removeXSLT = [[parser document] retain];
  }
  return [self xsltTransform:removeXSLT];
}
@end
