#import <Foundation/Foundation.h>
#import <GNUstepBase/GSXML.h>
#import <ical.h>
#import "Event.h"
#import "iCalStore.h"
#import "defines.h"

@interface Date(iCalendar)
- (id)initWithICalTime:(struct icaltimetype)time;
- (void)setDateToICalTime:(struct icaltimetype)time;
- (struct icaltimetype)iCalTime;
@end

@implementation Date(iCalendar)
- (id)initWithICalTime:(struct icaltimetype)time
{
  self = [super init];
  if (self)
    [self setDateToICalTime:time];
  return self;
}

- (void)setDateToICalTime:(struct icaltimetype)time
{
  _time = time;
}

- (struct icaltimetype)iCalTime
{
  return _time;
}
@end

@interface Event(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic;
- (BOOL)updateICalComponent:(icalcomponent *)ic;
@end

@implementation Event(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;
  icalproperty *pstart;
  icalproperty *pend;
  struct icaltimetype start;
  struct icaltimetype end;
  struct icaldurationtype diff;
  struct icalrecurrencetype rec;
  Date *date;

  self = [self init];
  if (self == nil)
    return nil;

  prop = icalcomponent_get_first_property(ic, ICAL_UID_PROPERTY);
  if (!prop) {
    NSLog(@"No UID");
    goto init_error;
  }
  [self setExternalRef:[NSString stringWithCString:icalproperty_get_uid(prop)]];
    
  prop = icalcomponent_get_first_property(ic, ICAL_SUMMARY_PROPERTY);
  if (!prop) {
    NSLog(@"No summary");
    goto init_error;
  }
  [self setTitle:[NSString stringWithCString:icalproperty_get_summary(prop) encoding:NSUTF8StringEncoding]];
  prop = icalcomponent_get_first_property(ic, ICAL_DESCRIPTION_PROPERTY);
  if (prop) {
    NSAttributedString *as = [[NSAttributedString alloc] initWithString:[NSString stringWithCString:icalproperty_get_description(prop) encoding:NSUTF8StringEncoding]];
    [self setDescriptionText:as];
    [as release];
  }

  pstart = icalcomponent_get_first_property(ic, ICAL_DTSTART_PROPERTY);
  if (!pstart) {
    NSLog(@"No start date");
    goto init_error;
  }
  start = icalproperty_get_dtstart(pstart);
  date = [[Date alloc] initWithICalTime:start];
  [self setStartDate:date andConstrain:NO];
  [self setEndDate:date];

  pend = icalcomponent_get_first_property(ic, ICAL_DTEND_PROPERTY);
  if (!pend) {
    prop = icalcomponent_get_first_property(ic, ICAL_DURATION_PROPERTY);
    if (!prop) {
      NSLog(@"No end date and no duration");
      goto init_error;
    }
    diff = icalproperty_get_duration(prop);
  } else {
    end = icalproperty_get_dtend(pend);
    diff = icaltime_subtract(end, start);
  }
  [self setDuration:icaldurationtype_as_int(diff) / 60];

  prop = icalcomponent_get_first_property(ic, ICAL_RRULE_PROPERTY);
  if (prop) {
    rec = icalproperty_get_rrule(prop);
    [date changeYearBy:10];
    switch (rec.freq) {
    case ICAL_DAILY_RECURRENCE:
      [self setInterval:RI_DAILY];
      [self setFrequency:rec.interval];
      [self setEndDate:date];
      break;
    case ICAL_WEEKLY_RECURRENCE:
      [self setInterval:RI_WEEKLY];
      [self setFrequency:rec.interval];
      [self setEndDate:date];
      break;
    case ICAL_MONTHLY_RECURRENCE:
      [self setInterval:RI_MONTHLY];
      [self setFrequency:rec.interval];
      [self setEndDate:date];
      break;
    case ICAL_YEARLY_RECURRENCE:
      [self setInterval:RI_YEARLY];
      [self setFrequency:rec.interval];
      [self setEndDate:date];
      break;
    default:
      NSLog(@"todo");
      break;
    }
  }
  [date release];
  return self;

 init_error:
  NSLog(@"Error creating Event from iCal component");
  [self release];
  return nil;
}

- (BOOL)updateICalComponent:(icalcomponent *)ic
{
  struct icaltimetype itime;
  icalproperty *prop;

  prop = icalcomponent_get_first_property(ic, ICAL_UID_PROPERTY);
  if (!prop) {
    /* FIXME : generate unique uid ? */
    prop = icalproperty_new_uid("SimpleAgenda.app");
    icalcomponent_add_property(ic, prop);
    [self setExternalRef:[NSString stringWithCString:icalproperty_get_uid(prop)]];
  }

  prop = icalcomponent_get_first_property(ic, ICAL_SUMMARY_PROPERTY);
  if (!prop) {
    prop = icalproperty_new_summary([title UTF8String]);
    icalcomponent_add_property(ic, prop);
  } else
    icalproperty_set_summary(prop, [title UTF8String]);

  if (descriptionText != nil) {
    prop = icalcomponent_get_first_property(ic, ICAL_DESCRIPTION_PROPERTY);
    if (!prop) {
      prop = icalproperty_new_description([[descriptionText string] UTF8String]);
      icalcomponent_add_property(ic, prop);
    } else
      icalproperty_set_description(prop, [[descriptionText string] UTF8String]);
  }

  prop = icalcomponent_get_first_property(ic, ICAL_DTSTART_PROPERTY);
  if (!prop) {
    prop = icalproperty_new_dtstart([startDate iCalTime]);
    icalcomponent_add_property(ic, prop);
  } else
    icalproperty_set_dtstart(prop, [startDate iCalTime]);

  prop = icalcomponent_get_first_property(ic, ICAL_DTEND_PROPERTY);
  if (!prop) {
    prop = icalcomponent_get_first_property(ic, ICAL_DURATION_PROPERTY);
    if (!prop) {
      prop = icalproperty_new_duration(icaldurationtype_from_int(duration * 60));
      icalcomponent_add_property(ic, prop);
    } else
      icalproperty_set_duration(prop, icaldurationtype_from_int(duration * 60));
  } else {
    itime = icaltime_add([startDate iCalTime], icaldurationtype_from_int(duration * 60));
    icalproperty_set_dtend(prop, itime);
  }
  return YES;
}
@end


@implementation iCalStore

- (icalcomponent *)getComponentForEvent:(Event *)evt
{
  NSString *uid = [evt externalRef];
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
      _writable = NO;
    _set = [[NSMutableSet alloc] initWithCapacity:32];
    if ([_config objectForKey:ST_DISPLAY])
      _displayed = [[_config objectForKey:ST_DISPLAY] boolValue];
    else
      _displayed = YES;
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
  _modified = YES;
  icalcomponent_remove_component(_icomp, ic);
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
    [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
  }
}

- (BOOL)contains:(Event *)evt
{
  return NO;
}

- (BOOL)isWritable
{
  return _writable;
}

- (BOOL)modified
{
  return _modified;
}

- (void)write
{
  NSData *data;
  char *text;
  
  if ([self isWritable] && _icomp && _modified) {
    text = icalcomponent_as_ical_string(_icomp);
    data = [NSData dataWithBytes:text length:strlen(text)];
    [_url setProperty:@"PUT" forKey:GSHTTPPropertyMethodKey];
    if ([_url setResourceData:data]) {
      NSLog(@"iCalStore written to %@", [_url absoluteString]);
      _modified = NO;
    }
  }
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
