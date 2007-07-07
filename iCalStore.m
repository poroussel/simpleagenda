#import <Foundation/Foundation.h>
#import <GNUstepBase/GSXML.h>
#import <ical.h>
#import "Event.h"
#import "iCalStore.h"
#import "defines.h"

@implementation iCalStore

- (icalcomponent *)getComponentForEvent:(Event *)evt
{
  NSString *uid = [evt UID];
  icalcomponent *ic;
  icalproperty *prop;

  for (ic = icalcomponent_get_first_component(_icomp, ICAL_VEVENT_COMPONENT); 
       ic != NULL; ic = icalcomponent_get_next_component(_icomp, ICAL_VEVENT_COMPONENT)) {
    prop = icalcomponent_get_first_property(ic, ICAL_UID_PROPERTY);
    if (prop) {
      if ([uid isEqual:[NSString stringWithCString:icalproperty_get_uid(prop)]])
	return ic;
    }
  }
  return NULL;
}

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
  Event *ev;
  icalcomponent *ic;

  if ([self needsRefresh]) {
    [_url setProperty:@"GET" forKey:GSHTTPPropertyMethodKey];
    data = [_url resourceDataUsingCache:NO];
    if (data) {
      text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      if (text) {
	if (_icomp)
	  icalcomponent_free(_icomp);
	_icomp = icalparser_parse_string([text cStringUsingEncoding:NSUTF8StringEncoding]);
	if (_icomp) {
	  [_set removeAllObjects];
	  for (ic = icalcomponent_get_first_component(_icomp, ICAL_VEVENT_COMPONENT); 
	       ic != NULL; ic = icalcomponent_get_next_component(_icomp, ICAL_VEVENT_COMPONENT)) {
	    ev = [[Event alloc] initWithICalComponent:ic];
	    if (ev)
	      [_set addObject:ev];
	  }
	}
	[_set makeObjectsPerform:@selector(setStore:) withObject:self];
	NSLog(@"iCalStore from %@ : loaded %d appointment(s)", [_url absoluteString], [_set count]);
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
  if (_icomp)
    icalcomponent_free(_icomp);
  [_set release];
  [_url release];
  [_config release];
  [_name release];
  [_lastModified release];
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
  icalcomponent *ic = icalcomponent_new(ICAL_VEVENT_COMPONENT);
  if ([evt updateICalComponent:ic]) {
    [evt setStore:self];
    [_set addObject:evt];
    icalcomponent_add_component(_icomp, ic);
    _modified = YES;
    if (![_url isFileURL])
      [self write];
    [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
  } else {
    icalcomponent_free(ic);
    [evt release];
  }
}

/*
 * FIXME : we should probably write asynchronously on
 * every change or every x minutes.
 * Do we need to read before writing ?
 */
- (void)delAppointment:(Event *)evt
{
  icalcomponent *ic = [self getComponentForEvent:evt];
  if (!ic) {
    NSLog(@"iCalendar component not found");
    return;
  }
  [_set removeObject:evt];
  icalcomponent_remove_component(_icomp, ic);
  _modified = YES;
  if (![_url isFileURL])
    [self write];
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

- (void)updateAppointment:(Event *)evt
{
  icalcomponent *ic = [self getComponentForEvent:evt];
  if (!ic) {
    NSLog(@"iCalendar component not found");
    return;
  }
  if ([evt updateICalComponent:ic]) {
    _modified = YES;
    if (![_url isFileURL])
      [self write];
    [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
  }
}

- (BOOL)contains:(Event *)evt
{
  return [_set containsObject:evt];
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
  NSData *data;
  char *text;
  
  if (_icomp) {
    text = icalcomponent_as_ical_string(_icomp);
    data = [NSData dataWithBytes:text length:strlen(text)];
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
