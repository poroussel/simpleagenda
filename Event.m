#import <Foundation/Foundation.h>
#import <string.h>
#import "Event.h"
#import "DateRange.h"

@implementation Event(NSCoding)
- (void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];
  [coder encodeObject:_startDate forKey:@"sdate"];
  [coder encodeInt:_duration forKey:@"duration"];
  [coder encodeObject:_location forKey:@"location"];
  [coder encodeBool:_allDay forKey:@"allDay"];
  [coder encodeObject:_rrule forKey:@"rrule"];
  [coder encodeBool:_sticky forKey:@"sticky"];
}
- (id)initWithCoder:(NSCoder *)coder
{
  [super initWithCoder:coder];
  _startDate = [[coder decodeObjectForKey:@"sdate"] retain];
  _duration = [coder decodeIntForKey:@"duration"];
  _location = [[coder decodeObjectForKey:@"location"] retain];
  if ([coder containsValueForKey:@"allDay"])
    _allDay = [coder decodeBoolForKey:@"allDay"];
  else
    _allDay = NO;
  if ([coder containsValueForKey:@"rrule"])
    _rrule = [[coder decodeObjectForKey:@"rrule"] retain];
  if ([coder containsValueForKey:@"sticky"])
    _sticky = [coder decodeBoolForKey:@"sticky"];
  else
    _sticky = NO;
  return self;
}
@end

@implementation Event
- (id)copy
{
  Event *new = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self]];
  [new generateUID];
  return new;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle
{
  self = [super initWithSummary:aTitle];
  if (self) {
    [self setStartDate:start];
    [self setDuration:minutes];
    [self setSticky:NO];
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_location);
  RELEASE(_startDate);
  RELEASE(_rrule);
  [super dealloc];
}

- (BOOL)isScheduledForDay:(Date *)day
{
  return [self intersectionWithDay:day].length > 0;
}

/*
 * Values are in seconds whereas time granularity in
 * all other Event methods is minute.
 * Worth changing ?
 */
- (NSRange)intersectionWithDay:(Date *)day
{
  NSEnumerator *enumerator;
  DateRange *range = AUTORELEASE([[DateRange alloc] initWithStart:_startDate duration:[self duration]*60]);

  if (!_rrule)
    return [range intersectionWithDay:day];
  enumerator = [_rrule enumeratorFromDate:_startDate length:[self duration]*60];
  while ((range = [enumerator nextObject])) {
    if ([range intersectsWithDay:day])
      return [range intersectionWithDay:day];
    if ([[range start] compare:day withTime:NO] > 0)
      break;
  }
  return NSMakeRange(0, 0);
}

- (Date *)nextActivationDate
{
  if (!_rrule)
    return _startDate;
  return nil;
}

- (NSString *)location
{
  return _location;
}

- (void)setLocation:(NSString *)location
{
  ASSIGN(_location, location);
}

- (BOOL)allDay
{
  return _allDay;
}

- (void)setAllDay:(BOOL)allDay
{
  /*
   * FIXME : why do we force startDate to being a date ?
   * What is the relation with the appointment being an
   * all day one ?
   */
  [_startDate setIsDate:allDay];
  _allDay = allDay;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<%@> from <%@> for <%d>", [self summary], [_startDate description], [self duration]];
}

- (NSString *)details
{
  if (_allDay)
    return @"all day";
  int minute = [_startDate minuteOfDay];
  return [NSString stringWithFormat:@"%dh%02d", minute / 60, minute % 60];
}

- (BOOL)contains:(NSString *)text
{
  if ([self summary] && [[self summary] rangeOfString:text options:NSCaseInsensitiveSearch].length > 0)
    return YES;
  if (_location && [_location rangeOfString:text options:NSCaseInsensitiveSearch].length > 0)
    return YES;
  if ([self text] && [[[self text] string] rangeOfString:text options:NSCaseInsensitiveSearch].length > 0)
    return YES;
  return NO;
}

- (int)duration
{
  if (_allDay)
    return 1440;
  return _duration;
}

- (Date *)startDate
{
  return _startDate;
}

- (RecurrenceRule *)rrule
{
  return _rrule;
}

- (BOOL)sticky
{
  return _sticky;
}

- (void)setDuration:(int)newDuration
{
  _duration = newDuration;
}

- (void)setStartDate:(Date *)newStartDate
{
  ASSIGNCOPY(_startDate, newStartDate);
}

- (void)setRRule:(RecurrenceRule *)arule
{
  ASSIGN(_rrule, arule);
}

- (void)setSticky:(BOOL)sticky
{
  _sticky = sticky;
}

- (NSEnumerator *)dateEnumerator
{
  return [_rrule enumeratorFromDate:_startDate];
}

- (NSEnumerator *)dateRangeEnumerator
{
  return [_rrule enumeratorFromDate:_startDate length:_allDay?86400:_duration*60];
}
@end

@implementation Event(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;
  icalproperty *pstart;
  icalproperty *pend;
  icalproperty *pdur;
  struct icaltimetype start;
  struct icaltimetype end;
  struct icaldurationtype diff;
  Date *date;
  const char *location;

  self = [super initWithICalComponent:ic];
  if (self == nil)
    return nil;

  pstart = icalcomponent_get_first_property(ic, ICAL_DTSTART_PROPERTY);
  if (!pstart) {
    NSLog(@"No start date");
    goto init_error;
  }
  start = icalproperty_get_dtstart(pstart);
  date = [[Date alloc] initWithICalTime:start];
  [self setStartDate:date];
  pend = icalcomponent_get_first_property(ic, ICAL_DTEND_PROPERTY);
  pdur = icalcomponent_get_first_property(ic, ICAL_DURATION_PROPERTY);
  if ((!pend && !pdur) || [date isDate])
    [self setAllDay:YES];
  else {
    if (!pend)
      diff = icalproperty_get_duration(pdur);
    else {
      end = icalproperty_get_dtend(pend);
      diff = icaltime_subtract(end, start);
    }
    [self setDuration:icaldurationtype_as_int(diff) / 60];
  }
  prop = icalcomponent_get_first_property(ic, ICAL_RRULE_PROPERTY);
  if (prop)
    _rrule = [[RecurrenceRule alloc] initWithICalRRule:icalproperty_get_rrule(prop)];
  [date release];
  location = icalcomponent_get_location(ic);
  if (location)
    [self setLocation:[NSString stringWithUTF8String:location]];
  prop = icalcomponent_get_first_property(ic, ICAL_X_PROPERTY);
  while (prop) {
    if (!strcmp(icalproperty_get_x_name(prop), "X-SIMPLEAGENDA-STICKY")) {
      [self setSticky:strcmp("YES", icalproperty_get_value_as_string(prop))];
    }
    prop = icalcomponent_get_next_property(ic, ICAL_X_PROPERTY);
  }
  return self;

 init_error:
  NSLog(@"Error creating Event from iCal component");
  [self release];
  return nil;
}

- (BOOL)updateICalComponent:(icalcomponent *)ic
{
  Date *end;
  icalproperty *prop;

  if (![super updateICalComponent:ic])
    return NO;

  [self deleteProperty:ICAL_LOCATION_PROPERTY fromComponent:ic];
  if ([self location])
    icalcomponent_add_property(ic, icalproperty_new_location([[self location] UTF8String]));

  [self deleteProperty:ICAL_DTSTART_PROPERTY fromComponent:ic];
  icalcomponent_add_property(ic, icalproperty_new_dtstart([_startDate UTCICalTime]));

  [self deleteProperty:ICAL_DTEND_PROPERTY fromComponent:ic];
  [self deleteProperty:ICAL_DURATION_PROPERTY fromComponent:ic];
  if (![self allDay])
    icalcomponent_add_property(ic, icalproperty_new_dtend(icaltime_add([_startDate UTCICalTime], icaldurationtype_from_int(_duration * 60))));
  else {
    end = [_startDate copy];
    [end incrementDay];
    icalcomponent_add_property(ic, icalproperty_new_dtend([end UTCICalTime]));
    [end release];
    /* OGo workaround ? */
    prop = icalcomponent_get_first_property(ic, ICAL_X_PROPERTY);
    while (prop) {
      if (!strcmp(icalproperty_get_x_name(prop), "X-MICROSOFT-CDO-ALLDAYEVENT"))
	icalcomponent_remove_property(ic, prop); 
      prop = icalcomponent_get_next_property(ic, ICAL_X_PROPERTY);
    }
    prop = icalproperty_new_from_string("X-MICROSOFT-CDO-ALLDAYEVENT:TRUE");
    icalcomponent_add_property(ic, prop);
  }

  prop = icalcomponent_get_first_property(ic, ICAL_X_PROPERTY);
  while (prop) {
    if (!strcmp(icalproperty_get_x_name(prop), "X-SIMPLEAGENDA-STICKY"))
      icalcomponent_remove_property(ic, prop); 
    prop = icalcomponent_get_next_property(ic, ICAL_X_PROPERTY);
  }
  if ([self sticky]) {
    prop = icalproperty_new_from_string("X-SIMPLEAGENDA-STICKY:TRUE");
    icalcomponent_add_property(ic, prop);
  }

  [self deleteProperty:ICAL_RRULE_PROPERTY fromComponent:ic];
  if (_rrule)
    icalcomponent_add_property(ic, icalproperty_new_rrule([_rrule iCalRRule]));
  return YES;
}

- (int)iCalComponentType
{
  return ICAL_VEVENT_COMPONENT;
}
@end
