/*
 * Based on ChronographerSource Appointment class
 */

#import <Foundation/Foundation.h>
#import "Event.h"

@implementation Event(NSCoding)
- (void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];
  [coder encodeObject:startDate forKey:@"sdate"];
  [coder encodeInt:duration forKey:@"duration"];
  [coder encodeObject:_location forKey:@"location"];
  [coder encodeBool:_allDay forKey:@"allDay"];
  [coder encodeObject:rrule forKey:@"rrule"];
}
- (id)initWithCoder:(NSCoder *)coder
{
  [super initWithCoder:coder];
  startDate = [[coder decodeObjectForKey:@"sdate"] retain];
  duration = [coder decodeIntForKey:@"duration"];
  _location = [[coder decodeObjectForKey:@"location"] retain];
  if ([coder containsValueForKey:@"allDay"])
    _allDay = [coder decodeBoolForKey:@"allDay"];
  else
    _allDay = NO;
  if ([coder containsValueForKey:@"rrule"])
    rrule = [[coder decodeObjectForKey:@"rrule"] retain];
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
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_location);
  RELEASE(startDate);
  RELEASE(rrule);
  [super dealloc];
}

- (BOOL)isScheduledForDay:(Date *)day
{
  NSEnumerator *enumerator;
  Date *start;
  Date *date;

  NSAssert(day != nil, @"Empty day argument");
  start = AUTORELEASE([startDate copy]);
  [start setDate:YES];
  if (!rrule)
    return [day compare:start] == 0;
  enumerator = [rrule enumeratorFromDate:start];
  while ((date = [enumerator nextObject])) {
    if ([date compare:day] == 0)
      return YES;
    if ([date compare:day] > 0)
      break;
  }
  return NO;
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
  [startDate setDate:allDay];
  _allDay = allDay;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<%@> from <%@> for <%d>", [self summary], [startDate description], [self duration]];
}

- (NSString *)details
{
  if ([self allDay])
    return @"all day";
  int minute = [[self startDate] minuteOfDay];
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
  return duration;
}

- (Date *)startDate
{
  return startDate;
}

- (RecurrenceRule *)rrule
{
  return rrule;
}

- (void)setDuration:(int)newDuration
{
  duration = newDuration;
}

- (void)setStartDate:(Date *)newStartDate
{
  ASSIGNCOPY(startDate, newStartDate);
}

- (void)setRRule:(RecurrenceRule *)arule
{
  /* RecurrenceRules can't be modified, no need to copy */
  ASSIGN(rrule, arule);
}

- (NSEnumerator *)dateEnumerator
{
  return [rrule enumeratorFromDate:startDate];
}

- (NSEnumerator *)dateRangeEnumerator
{
  return [rrule enumeratorFromDate:startDate length:_allDay?86400:duration*60];
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
    rrule = [[RecurrenceRule alloc] initWithICalRRule:icalproperty_get_rrule(prop)];
  [date release];
  location = icalcomponent_get_location(ic);
  if (location)
    [self setLocation:[NSString stringWithUTF8String:location]];
  return self;

 init_error:
  NSLog(@"Error creating Event from iCal component");
  [self release];
  return nil;
}

- (icalcomponent *)asICalComponent
{
  icalcomponent *ic = icalcomponent_new(ICAL_VEVENT_COMPONENT);
  if (!ic) {
    NSLog(@"Couldn't create iCalendar component");
    return NULL;
  }
  if (![self updateICalComponent:ic]) {
    icalcomponent_free(ic);
    return NULL;
  }
  return ic;
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
  icalcomponent_add_property(ic, icalproperty_new_dtstart([startDate iCalTime]));

  [self deleteProperty:ICAL_DTEND_PROPERTY fromComponent:ic];
  [self deleteProperty:ICAL_DURATION_PROPERTY fromComponent:ic];
  if (![self allDay])
    icalcomponent_add_property(ic, icalproperty_new_dtend(icaltime_add([startDate iCalTime], icaldurationtype_from_int(duration * 60))));
  else {
    end = [startDate copy];
    [end incrementDay];
    icalcomponent_add_property(ic, icalproperty_new_dtend([end iCalTime]));
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

  [self deleteProperty:ICAL_RRULE_PROPERTY fromComponent:ic];
  if (rrule)
    icalcomponent_add_property(ic, icalproperty_new_rrule([rrule iCalRRule]));
  return YES;
}

- (int)iCalComponentType
{
  return ICAL_VEVENT_COMPONENT;
}
@end
