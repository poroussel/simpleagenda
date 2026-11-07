#import <GNUstepBase/GSXML.h>
#import <GNUstepBase/GSMime.h>
#import "NSString+SimpleAgenda.h"
#import "WebDAVResource.h"

static NSString *logKey = @"WebDAVResource";

@implementation WebDAVResource
- (void)dealloc
{
  RELEASE(_user);
  RELEASE(_password);
  RELEASE(_url);
  RELEASE(_lastModified);
  RELEASE(_data);
  RELEASE(_reason);
  RELEASE(_etag);
  DEALLOC;
}

- (void)setURL:(NSURL *)anURL
{
  NSString *absolute = [anURL absoluteString];
  NSRange range = [absolute rangeOfString:@"webcal"];
  if (range.length > 0 && range.location == 0)
      absolute = [absolute stringByReplacingCharactersInRange:range withString:@"http"];
  ASSIGN(_url, [NSURL URLWithString:absolute]);

  // FIXME : this is more than ugly but NSURL -initWithScheme:user:password:host:port:path:query:fragment
  // doesn't work as expected (it double escapes user and password)
  if ([_user length] > 0 && [_password length] > 0 && ![_url user] && ![_url password]) {
    absolute = [_url absoluteString];
    range = [absolute rangeOfString:[NSString stringWithFormat:@"%@://", [_url scheme]]];
    if (range.length > 0 && range.location == 0) {
      absolute = [absolute stringByReplacingCharactersInRange:range
                  withString:[NSString stringWithFormat:@"%@://%@:%@@", [_url scheme], _user, _password]];
      ASSIGN(_url, [NSURL URLWithString:absolute]);
    }
  }
  _handleClass = [NSURLHandle URLHandleClassForURL:_url];
}

- (id)initWithURL:(NSURL *)url username:(NSString *)username password:(NSString *)password
{
  if ((self = [super init])) {
    if ([username length] > 0)
      ASSIGN(_user, [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLUserAllowedCharacterSet]]);
    if ([password length] > 0)
      ASSIGN(_password, [password stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPasswordAllowedCharacterSet]]);
    [self setURL:url];
  }
  return self;
}

- (BOOL)requestWithMethod:(NSString *)method body:(NSData *)body attributes:(NSDictionary *)attributes
{
  NSEnumerator *keys;
  NSString *key;
  NSData *data;
  NSString *property;
  NSURLHandle *handle;
  int redirectCount = 0;

restart:
  handle = [[_handleClass alloc] initWithURL:_url cached:NO];
  [handle writeProperty:method forKey:GSHTTPPropertyMethodKey];
  if (attributes) {
    keys = [attributes keyEnumerator];
    while ((key = [keys nextObject]))
      [handle writeProperty:[attributes objectForKey:key] forKey:key];
  }
  if (_etag && ([method isEqual:@"PUT"] || [method isEqual:@"DELETE"]))
    [handle writeProperty:[NSString stringWithFormat:@"([%@])", _etag] forKey:@"If"];
  if (body)
    [handle writeData:body];
  if (attributes)
    NSDebugLLog(logKey, @"requestWithMethod %@ %@ (%@)", method, [_url anonymousAbsoluteString], [attributes description]);
  else
    NSDebugLLog(logKey, @"requestWithMethod %@ %@", method, [_url anonymousAbsoluteString]);
  DESTROY(_data);
  data = [handle resourceData];
  /* FIXME : this is more than ugly */
  if ([_url isFileURL])
    _httpStatus = data ? 200 : 199;
  else
    _httpStatus = [[handle propertyForKeyIfAvailable:NSHTTPPropertyStatusCodeKey] intValue];

  /* FIXME : why do we have to check for httpStatus == 0 */
  if ((_httpStatus == 0 ||_httpStatus == 301 || _httpStatus == 302) &&
      [handle propertyForKey:@"Location"] != nil && redirectCount < 10) {
    NSDebugLLog(logKey, @"requestWithMethod redirection to %@", [handle propertyForKey:@"Location"]);
    [self setURL:[NSURL URLWithString:[handle propertyForKey:@"Location"]]];
    RELEASE(handle);
    redirectCount++;
    goto restart;
  }

  NSDebugLLog(logKey, @"requestWithMethod status %d", _httpStatus);
  property = [handle propertyForKeyIfAvailable:NSHTTPPropertyStatusReasonKey];
  if (property)
    ASSIGN(_reason, property);
  else
    DESTROY(_reason);
  if (_httpStatus < 200 || _httpStatus > 299) {
    NSLog(@"Error %@ on %@ : %d %@", method, [_url anonymousAbsoluteString], _httpStatus, _reason);
    RELEASE(handle);
    return NO;
  }

  if (data)
    ASSIGN(_data, data);

  if ([method isEqual:@"GET"]) {
    property = [handle propertyForKeyIfAvailable:@"Last-Modified"];
    if (!_lastModified || (property && ![property isEqual:_lastModified])) {
      _dataChanged = YES;
      NSDebugLLog(logKey, @"requestWithMethod lastModified dataChanged [%@]", property);
      ASSIGN(_lastModified, property);
    }
    property = [handle propertyForKeyIfAvailable:@"ETag"];
    if (!_etag || (property && ![property isEqual:_etag])) {
      _dataChanged = YES;
      NSDebugLLog(logKey, @"requestWithMethod etag dataChanged [%@]", property);
      ASSIGN(_etag, property);
    }
  }
  RELEASE(handle);
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
- (void)updateAttributes
{
  GSXMLParser *parser;
  GSXPathContext *xpc;
  GSXPathString *result;

  if ([self propfind:nil attributes:nil]) {
    parser = [GSXMLParser parserWithData:[self data]];
    if ([parser parse]) {
      xpc = [[GSXPathContext alloc] initWithDocument:[[parser document] strippedDocument]];
      result = (GSXPathString *)[xpc evaluateExpression:GETETAG];
      if (result && [[result stringValue] length] > 0)
	      ASSIGN(_etag, [result stringValue]);
      result = (GSXPathString *)[xpc evaluateExpression:GETLASTMODIFIED];
      if (result && [[result stringValue] length] > 0)
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
  if (![self user] || ![self password])
    return as;

  NSURLComponents *comp = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:NO];
  NSString *toReplace = [NSString stringWithFormat:@"%@:%@@", [comp percentEncodedUser], [comp percentEncodedPassword]];
  return [as stringByReplacingOccurrencesOfString:toReplace withString:@"xxx:yyy@"];
}
@end

/*
 * Copy of a document without any namespace, so XPath expressions can use
 * the local names (servers use different prefixes and default namespaces).
 *
 * This used to be an XSLT transformation, but gnustep-base
 * -[GSXMLDocument xsltTransform:] leaks the compiled stylesheet on every
 * call (about 20KB, so on every PROPFIND response) and modifies the
 * stylesheet document. Copying the tree with the public GSXML API needs
 * neither libxslt nor a fixed gnustep-base.
 */
static NSInteger elementType, textType, cdataType, commentType, piType;

static void copyAttributes(GSXMLNode *from, GSXMLNode *to)
{
  /* -attributes is keyed by local names */
  NSDictionary *attributes = [from attributes];
  NSEnumerator *keys = [attributes keyEnumerator];
  NSString *key;

  while ((key = [keys nextObject]))
    [to setObject:[attributes objectForKey:key] forKey:key];
}

static void copyChildren(GSXMLNode *from, GSXMLNode *to)
{
  GSXMLNode *child, *copy;
  NSInteger type;

  for (child = [from firstChild]; child != nil; child = [child next]) {
    type = [child type];
    if (type == elementType) {
      copy = [to makeChildWithNamespace:nil name:[child name] content:nil];
      copyAttributes(child, copy);
      copyChildren(child, copy);
    } else if (type == textType || type == cdataType) {
      if ([child content])
	[to makeText:[child content]];
    } else if (type == commentType) {
      [to makeComment:[child content]];
    } else if (type == piType) {
      [to makePI:[child name] content:[child content]];
    }
    /*
     * Unsubstituted entity references are dropped, as the XSLT version did :
     * expanding them here would bypass libxml2 protections against
     * exponential entity expansion. DAV servers don't use them.
     */
  }
}

@implementation GSXMLDocument(SimpleAgenda)
- (GSXMLDocument *)strippedDocument
{
  GSXMLDocument *stripped = [GSXMLDocument documentWithVersion:@"1.0"];
  GSXMLNode *root = [self root];
  GSXMLNode *copy;

  if (elementType == 0) {
    elementType = [GSXMLNode typeFromDescription:@"XML_ELEMENT_NODE"];
    textType = [GSXMLNode typeFromDescription:@"XML_TEXT_NODE"];
    cdataType = [GSXMLNode typeFromDescription:@"XML_CDATA_SECTION_NODE"];
    commentType = [GSXMLNode typeFromDescription:@"XML_COMMENT_NODE"];
    piType = [GSXMLNode typeFromDescription:@"XML_PI_NODE"];
  }
  if (root != nil) {
    copy = [stripped makeNodeWithNamespace:nil name:[root name] content:nil];
    copyAttributes(root, copy);
    [stripped setRoot:copy];
    copyChildren(root, copy);
  }
  return stripped;
}
@end
