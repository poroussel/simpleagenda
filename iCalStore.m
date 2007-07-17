#import <Foundation/Foundation.h>
#import <GNUstepBase/GSXML.h>
#import "Event.h"
#import "iCalStore.h"
#import "defines.h"

@implementation iCalStore

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

/* FIXME : reading shouldn't delete local unsaved modifications */
- (BOOL)read
{
  NSSet *items;
  NSData *data;
  NSString *text;
  NSEnumerator *enumerator;
  Event *apt;

  if ([self needsRefresh]) {
    [_url setProperty:@"GET" forKey:GSHTTPPropertyMethodKey];
    data = [_url resourceDataUsingCache:NO];
    if (data) {
      text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      if (text && [_tree parseString:text]) {
	items = [_tree events];
	[items makeObjectsPerform:@selector(setStore:) withObject:self];
	enumerator = [items objectEnumerator];
	while ((apt = [enumerator nextObject]))
	  [_data setValue:apt forKey:[apt UID]];
	NSLog(@"iCalStore from %@ : loaded %d appointment(s)", [_url absoluteString], [_data count]);
	[text release];
      } else
	NSLog(@"Couldn't parse data from %@", [_url absoluteString]);
    } else
      NSLog(@"No data read from %@", [_url absoluteString]);
    return YES;
  }
  return NO;
}

- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
			 [NSArchiver archivedDataWithRootObject:[NSColor blueColor]], ST_COLOR,
		       [NSNumber numberWithBool:NO], ST_RW,
		       [NSNumber numberWithBool:YES], ST_DISPLAY,
		       nil, nil];
}

- (id)initWithName:(NSString *)name
{
  NSString *location;

  self = [super init];
  if (self) {
    _tree = [iCalTree new];
    _config = [[ConfigManager alloc] initForKey:name withParent:nil];
    [_config registerDefaults:[self defaults]];
    _url = [[NSURL alloc] initWithString:[_config objectForKey:ST_URL]];
    if (_url == nil) {
      NSLog(@"%@ isn't a valid url", [_config objectForKey:ST_URL]);
      [self release];
      return nil;
    }
    if ([_url resourceDataUsingCache:NO] == nil) {
      location = [_url propertyForKey:@"Location"];
      if (!location) {
	NSLog(@"Couldn't read data from %@", [_config objectForKey:ST_URL]);
	[self release];
	return nil;
      }
      _url = [_url initWithString:location];
      if (_url)
	NSLog(@"%@ redirected to %@", name, location);
      else {
	NSLog(@"%@ isn't a valid url", location);
	[self release];
	return nil;
      }
    }
    _name = [name copy];
    _modified = NO;
    _lastModified = nil;
    _writable = [[_config objectForKey:ST_RW] boolValue];
    _displayed = [[_config objectForKey:ST_DISPLAY] boolValue];
    _data = [[NSMutableDictionary alloc] initWithCapacity:32];
    [self read]; 

    if (![_url isFileURL]) {
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
  }
  return self;
}

+ (id)storeNamed:(NSString *)name
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] initWithName:name]);
}

- (void)dealloc
{
  [_refreshTimer invalidate];
  [self write];
  [_data release];
  [_url release];
  [_config release];
  [_name release];
  [_lastModified release];
  [_tree release];
  [super dealloc];
}

- (void)refreshData:(NSTimer *)timer
{
  if ([self read])
    [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

- (NSEnumerator *)enumerator
{
  return [_data objectEnumerator];
}

- (void)add:(Event *)evt
{
  if ([_tree add:evt]) {
    [evt setStore:self];
    [_data setValue:evt forKey:[evt UID]];
    _modified = YES;
    if (![_url isFileURL])
      [self write];
    [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
  }
}

/*
 * FIXME : we should probably write asynchronously on
 * every change or every x minutes.
 * Do we need to read before writing ?
 */
- (void)remove:(NSString *)uid
{
  if ([_tree remove:[_data objectForKey:uid]]) {
    [_data removeObjectForKey:uid];
    _modified = YES;
    if (![_url isFileURL])
      [self write];
    [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
  }
}

- (void)update:(NSString *)uid with:(Event *)evt
{
  if ([_tree update:evt]) {
    _modified = YES;
    if (![_url isFileURL])
      [self write];
    [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
  }
}

- (BOOL)contains:(NSString *)uid
{
  return [_data objectForKey:uid] != nil;
}

- (BOOL)isWritable
{
  return _writable;
}

- (void)setIsWritable:(BOOL)writable
{
  if (!writable)
    [self write];
  _writable = writable;
  [_config setObject:[NSNumber numberWithBool:_writable] forKey:ST_RW];
}

- (BOOL)modified
{
  return _modified;
}

- (BOOL)write
{
  NSData *data = [[_tree iCalTreeAsString] dataUsingEncoding:NSUTF8StringEncoding];
  
  if (data) {
    [_url setProperty:@"PUT" forKey:GSHTTPPropertyMethodKey];
    if ([_url setResourceData:data]) {
      NSLog(@"iCalStore written to %@", [_url absoluteString]);
      _modified = NO;
      return YES;
    }
    NSLog(@"Unable to write to %@, make this store read only", [_url absoluteString]);
    [self setIsWritable:NO];
    return NO;
  }
  return YES;
}

- (NSString *)description
{
  return _name;
}

- (NSColor *)eventColor
{
  NSData *theData =[_config objectForKey:ST_COLOR];
  return [NSUnarchiver unarchiveObjectWithData:theData];
}

- (void)setEventColor:(NSColor *)color
{
  NSData *data = [NSArchiver archivedDataWithRootObject:color];
  [_config setObject:data forKey:ST_COLOR];
}

- (BOOL)displayed
{
  return _displayed;
}

- (void)setDisplayed:(BOOL)state
{
  _displayed = state;
  [_config setObject:[NSNumber numberWithBool:_displayed] forKey:ST_DISPLAY];
}

@end
