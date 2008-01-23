/*
 * Based on ChronographerSource Appointment class
 */

#import <Foundation/Foundation.h>
#import "Event.h"

@implementation Event(NSCoding)
-(void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];
  [coder encodeObject:startDate forKey:@"sdate"];
  [coder encodeObject:endDate forKey:@"edate"];
  [coder encodeInt:interval forKey:@"interval"];
  [coder encodeInt:frequency forKey:@"frequency"];
  [coder encodeInt:duration forKey:@"duration"];
  [coder encodeObject:_location forKey:@"location"];
  [coder encodeBool:_allDay forKey:@"allDay"];
}
-(id)initWithCoder:(NSCoder *)coder
{
  [super initWithCoder:coder];
  startDate = [[coder decodeObjectForKey:@"sdate"] retain];
  endDate = [[coder decodeObjectForKey:@"edate"] retain];
  interval = [coder decodeIntForKey:@"interval"];
  frequency = [coder decodeIntForKey:@"frequency"];
  duration = [coder decodeIntForKey:@"duration"];
  _location = [[coder decodeObjectForKey:@"location"] retain];
  if ([coder containsValueForKey:@"allDay"])
    _allDay = [coder decodeBoolForKey:@"allDay"];
  else
    _allDay = NO;
  return self;
}
@end

@implementation Event
- (id)copy
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
  Event *new = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  [new generateUID];
  return new;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle
{
  self = [self initWithSummary:aTitle];
  if (self) {
    [self setStartDate:start];
    [self setDuration:minutes];
  }
  return self;
}

- (void)dealloc
{
  [super dealloc];
  RELEASE(_location);
  RELEASE(startDate);
  RELEASE(endDate);
}

/*
 * Code adapted from ChronographerSource Appointment:isScheduledFor
 */
- (BOOL)isScheduledForDay:(Date *)day
{
  NSAssert(day != nil, @"Empty day argument");
  if ([startDate compare:day] > 0 || (endDate && [endDate compare:day] < 0))
    return NO;
  switch (interval) {
  case RI_NONE:
    return [day compare:startDate] == 0;
  case RI_DAILY:
    return ((frequency == 1) ||
	    ([startDate daysUntil: day] % frequency) == 0);
  case RI_WEEKLY:
    return (([startDate weekday] == [day weekday]) &&
	    ((frequency == 1) ||
	     (([startDate weeksUntil: day] % frequency) == 0)));
  case RI_MONTHLY:
    return (([startDate dayOfMonth] == [day dayOfMonth]) &&
	    ((frequency == 1) ||
	     (([startDate monthsUntil: day] % frequency) == 0)));
  case RI_YEARLY:
    return ((([startDate dayOfMonth] == [day dayOfMonth]) &&
	     ([startDate monthOfYear] == [day monthOfYear])) &&
	    ((frequency == 1) ||
	     (([startDate yearsUntil: day] % frequency) == 0)));
  }
  return NO;
}

- (BOOL)isScheduledBetweenDay:(Date *)start andDay:(Date *)end
{
  int nd;
  Date *work = [start copy];

  for (nd = 0; nd < [start daysUntil:end] + 1; nd++) {
    if ([self isScheduledForDay:work]) {
      [work release];
      return YES;
    }
    [work incrementDay];
  }
  [work release];
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
  return [NSString stringWithFormat:@"<%@> from <%@> for <%d> to <%@> (%d)", [self summary], [startDate description], [self duration], [endDate description], interval];
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

- (int)frequency
{
  return frequency;
}

- (Date *)startDate
{
  return startDate;
}

- (Date *)endDate
{
  return endDate;
}

- (int)interval
{
  return interval;
}

- (void)setDuration:(int)newDuration
{
  duration = newDuration;
}

- (void)setFrequency:(int)newFrequency
{
  frequency = newFrequency;
}

- (void)setStartDate:(Date *)newStartDate
{
  ASSIGNCOPY(startDate, newStartDate);
}

- (void)setEndDate:(Date *)date
{
  ASSIGNCOPY(endDate, date);
}

- (void)setInterval:(int)newInterval
{
  interval = newInterval;
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
  struct icalrecurrencetype rec;
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
  if (prop) {
    rec = icalproperty_get_rrule(prop);
    switch (rec.freq) {
    case ICAL_DAILY_RECURRENCE:
      [self setInterval:RI_DAILY];
      [self setFrequency:rec.interval];
      break;
    case ICAL_WEEKLY_RECURRENCE:
      [self setInterval:RI_WEEKLY];
      [self setFrequency:rec.interval];
      break;
    case ICAL_MONTHLY_RECURRENCE:
      [self setInterval:RI_MONTHLY];
      [self setFrequency:rec.interval];
      break;
    case ICAL_YEARLY_RECURRENCE:
      [self setInterval:RI_YEARLY];
      [self setFrequency:rec.interval];
      break;
    default:
      NSLog(@"ToDo");
      break;
    }
    if (!icaltime_is_null_time(rec.until)) {
      [date setDateToICalTime:rec.until];
      [self setEndDate:date];
    }
  }
  [date release];
  location = icalcomponent_get_location(ic);
  if (location)
    [self setLocation:[NSString stringWithCString:location encoding:NSUTF8StringEncoding]];
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
  struct icalrecurrencetype irec;
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
  if (interval != RI_NONE) {
    icalrecurrencetype_clear(&irec);
    switch (interval) {
    case RI_DAILY:
      irec.freq = ICAL_DAILY_RECURRENCE;
      break;
    case RI_WEEKLY:
      irec.freq = ICAL_WEEKLY_RECURRENCE;
      break;
    case RI_MONTHLY:
      irec.freq = ICAL_MONTHLY_RECURRENCE;
      break;
    case RI_YEARLY:
      irec.freq = ICAL_YEARLY_RECURRENCE;
      break;
    default:
      NSLog(@"ToDo");
    }
    if (endDate != nil)
      irec.until = [endDate iCalTime];
    else
      irec.until = icaltime_null_time();
    icalcomponent_add_property(ic, icalproperty_new_rrule(irec));
  }
  return YES;
}

- (int)iCalComponentType
{
  return ICAL_VEVENT_COMPONENT;
}
@end

