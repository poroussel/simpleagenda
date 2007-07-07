/*
 * Based on ChronographerSource Appointment class
 */

#import <Foundation/Foundation.h>
#import "Event.h"

@implementation Event(NSCoding)
-(void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:title forKey:@"title"];
  [coder encodeObject:[descriptionText string] forKey:@"descriptionText"];
  [coder encodeObject:startDate forKey:@"sdate"];
  [coder encodeObject:endDate forKey:@"edate"];
  [coder encodeInt:interval forKey:@"interval"];
  [coder encodeInt:frequency forKey:@"frequency"];
  [coder encodeInt:duration forKey:@"duration"];
  [coder encodeInt:scheduleLevel forKey:@"scheduleLevel"];
  [coder encodeObject:_location forKey:@"location"];
  [coder encodeBool:_allDay forKey:@"allDay"];
  [coder encodeObject:_uid forKey:@"uid"];
}

-(id)initWithCoder:(NSCoder *)coder
{
  title = [[coder decodeObjectForKey:@"title"] retain];
  descriptionText = [[NSAttributedString alloc] initWithString:[coder decodeObjectForKey:@"descriptionText"]];
  startDate = [[coder decodeObjectForKey:@"sdate"] retain];
  endDate = [[coder decodeObjectForKey:@"edate"] retain];
  interval = [coder decodeIntForKey:@"interval"];
  frequency = [coder decodeIntForKey:@"frequency"];
  duration = [coder decodeIntForKey:@"duration"];
  scheduleLevel = [coder decodeIntForKey:@"scheduleLevel"];
  _location = [[coder decodeObjectForKey:@"location"] retain];
  if ([coder containsValueForKey:@"allDay"])
    _allDay = [coder decodeBoolForKey:@"allDay"];
  else
    _allDay = NO;
  if ([coder containsValueForKey:@"uid"])
    _uid = [[coder decodeObjectForKey:@"uid"] retain];
  else
    [self generateUID];
  return self;
}

@end

@implementation Event

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle
{
  [self init];
  [self setStartDate:start];
  [self setTitle:aTitle];
  [self setDuration:minutes];
  [self generateUID];
  return self;
}

- (void)dealloc
{
  [super dealloc];
  RELEASE(title);
  RELEASE(descriptionText);
  RELEASE(_store);
  RELEASE(_location);
  RELEASE(_uid);
  RELEASE(startDate);
  RELEASE(endDate);
}

/*
 * Code adapted from ChronographerSource Appointment:isScheduledFor
 */
- (BOOL)isScheduledForDay:(Date *)day
{
  NSAssert(day != nil, @"Empty day argument");
  if ([day daysUntil:startDate] > 0 || [day daysSince:endDate] > 0)
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

/*
 * FIXME : this should possibly be isEqual:
 * but we would need to override hash:
 */
- (NSComparisonResult)compare:(id)evt
{
  NSAssert([evt isKindOfClass:[Event class]], @"Wrong class");
  return [[self UID] compare:[evt UID]];
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

- (id <AgendaStore>)store
{
  return _store;
}

- (void)setStore:(id <AgendaStore>)store
{
  ASSIGN(_store, store);
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
  _allDay = allDay;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<%@> from <%@> for <%d> to <%@> (%d)", [self title], [startDate description], [self duration], [endDate description], interval];
}

- (NSString *)details
{
  if ([self allDay])
    return @"all day";
  int minute = [[self startDate] minuteOfDay];
  return [NSString stringWithFormat:@"%dh%02d", minute / 60, minute % 60];
}

- (void)generateUID
{
  Date *now = [Date date];
  static Date *lastDate;
  static int counter;

  if (!lastDate)
    ASSIGNCOPY(lastDate, [Date date]);
  else {
    if (![lastDate compareTime:now])
      counter++;
    else {
      ASSIGNCOPY(lastDate, now);
      counter = 0;
    }
  }
  [self setUID:[NSString stringWithFormat:@"SimpleAgenda-%@%d-%@", 
			 [[Date date] description], 
			 counter,
			 [[NSHost currentHost] name]]];
  NSLog([self UID]);
}

- (NSAttributedString *)descriptionText
{
  return descriptionText;
}

- (NSString *)title
{
  return title;
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

- (NSString *)UID
{
  return _uid;
}

- (void)setDescriptionText:(NSAttributedString *)description
{
  ASSIGN(descriptionText, description);
}

- (void)setTitle:(NSString *)newTitle
{
  ASSIGN(title, newTitle);
}

- (void)setDuration:(int)newDuration
{
  duration = newDuration;
  [self setAllDay:(newDuration == 1440)];
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

- (void)setUID:(NSString *)aUid;
{
  ASSIGNCOPY(_uid, aUid);
}

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
  [self setUID:[NSString stringWithCString:icalproperty_get_uid(prop)]];
    
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
  [self setStartDate:date];
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
      NSLog(@"ToDo");
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

- (id)initWithICalString:(NSString *)string;
{
  icalcomponent *root = icalparser_parse_string([string cStringUsingEncoding:NSUTF8StringEncoding]);
  icalcomponent *ic;

  if (root) {
    ic = icalcomponent_get_first_component(root, ICAL_VEVENT_COMPONENT);
    if (!ic)
      goto init_error;
    self = [self initWithICalComponent:ic];
    icalcomponent_free(root);
    return self;
  }
 init_error:
  NSLog(@"Unable to parse string as an iCalendar");
  icalcomponent_free(root);
  [self release];
  return nil;
}

- (BOOL)updateICalComponent:(icalcomponent *)ic
{
  struct icaltimetype itime;
  struct icalrecurrencetype irec;
  icalproperty *prop;

  prop = icalcomponent_get_first_property(ic, ICAL_UID_PROPERTY);
  if (!prop) {
    prop = icalproperty_new_uid([[self UID] cString]);
    icalcomponent_add_property(ic, prop);
    [self setUID:[NSString stringWithCString:icalproperty_get_uid(prop)]];
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

  prop = icalcomponent_get_first_property(ic, ICAL_RRULE_PROPERTY);
  if (interval != RI_NONE) {
    icalrecurrencetype_clear(&irec);
    if (!prop) {
      prop = icalproperty_new_rrule(irec);
      icalcomponent_add_property(ic, prop);
    }
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
    irec.until = [endDate iCalTime];
    icalproperty_set_rrule(prop, irec);
  } else if (prop)
    icalcomponent_remove_property(ic, prop);
  return YES;
}

- (NSString *)eventAsICalendarString
{
  NSString *res = nil;
  icalcomponent *root = icalcomponent_vanew(ICAL_VCALENDAR_COMPONENT,
					    icalproperty_new_version("1.0"),
					    icalproperty_new_prodid("-//Octets//NONSGML SimpleAgenda Calendar//EN"),
					    0);
  icalcomponent *ic = icalcomponent_new(ICAL_VEVENT_COMPONENT);
  icalcomponent_add_component(root, ic);
  if ([self updateICalComponent:ic])
    res = [NSString stringWithUTF8String:icalcomponent_as_ical_string(root)];
  icalcomponent_free(root);
  return res;
}
@end

