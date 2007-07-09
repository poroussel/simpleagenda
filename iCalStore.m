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
  NSData *data;
  NSString *text;

  if ([self needsRefresh]) {
    [_url setProperty:@"GET" forKey:GSHTTPPropertyMethodKey];
    data = [_url resourceDataUsingCache:NO];
    if (data) {
      text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      if (text && [_tree parseString:text]) {
	[_set setSet:[_tree events]];
	[_set makeObjectsPerform:@selector(setStore:) withObject:self];
	NSLog(@"iCalStore from %@ : loaded %d appointment(s)", [_url absoluteString], [_set count]);
	[text release];
      } else
	NSLog(@"Couldn't parse data from %@", [_url absoluteString]);
    } else
      NSLog(@"No data read from %@", [_url absoluteString]);
    return YES;
  }
  return NO;
}

- (id)initWithName:(NSString *)name forManager:(id)manager
{
  NSString *location;

  self = [super init];
  if (self) {
    _tree = [iCalTree new];
    _delegate = manager;
    _config = [[ConfigManager alloc] initForKey:name withParent:nil];
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
    if ([_config objectForKey:ST_RW])
      _writable = [[_config objectForKey:ST_RW] boolValue];
    else
      [self setIsWritable:NO];
    _set = [[NSMutableSet alloc] initWithCapacity:32];
    if ([_config objectForKey:ST_DISPLAY])
      _displayed = [[_config objectForKey:ST_DISPLAY] boolValue];
    else
      [self setDisplayed:YES];
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

+ (id)storeNamed:(NSString *)name forManager:(id)manager
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] initWithName:name 
								  forManager:manager]);
}

- (void)dealloc
{
  [_refreshTimer invalidate];
  [self write];
  [_set release];
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
  return [_set objectEnumerator];
}

- (void)addAppointment:(Event *)evt
{
  if ([_tree add:evt]) {
    [evt setStore:self];
    [_set addObject:evt];
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
- (void)delAppointment:(Event *)evt
{
  if ([_tree remove:evt]) {
    [_set removeObject:evt];
    _modified = YES;
    if (![_url isFileURL])
      [self write];
    [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
  }
}

- (void)updateAppointment:(Event *)evt
{
  if ([_tree update:evt]) {
    _modified = YES;
    if (![_url isFileURL])
      [self write];
    [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
  }
}

- (BOOL)contains:(Event *)evt
{
  NSEnumerator *enumerator = [_set objectEnumerator];
  Event *apt;

  while ((apt = [enumerator nextObject])) {
    /* FIXME : use isEqual: ? */
    if (![apt compare:evt])
      return YES;
  }
  return NO;
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
  NSColor *aColor = nil;
  NSData *theData =[_config objectForKey:ST_COLOR];

  if (theData)
    aColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
  else {
    aColor = [NSColor blueColor];
    [self setEventColor:aColor];
  }
  return aColor;
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
