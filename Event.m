/*
 * Based on ChronographerSource Appointment class
 */

#import <Foundation/Foundation.h>
#import "Event.h"

@implementation Event(NSCoding)

-(void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:title forKey:@"title"];
  // FIXME : we encode a simple string, losing the attributes
  [coder encodeObject:[descriptionText string] forKey:@"descriptionText"];
  [coder encodeObject:startDate forKey:@"sdate"];
  [coder encodeObject:endDate forKey:@"edate"];
  [coder encodeInt:interval forKey:@"interval"];
  [coder encodeInt:frequency forKey:@"frequency"];
  [coder encodeInt:duration forKey:@"duration"];
  [coder encodeInt:scheduleLevel forKey:@"scheduleLevel"];
  [coder encodeObject:_location forKey:@"location"];
  [coder encodeBool:_allDay forKey:@"allDay"];
}

-(id)initWithCoder:(NSCoder *)coder
{
  title = [[coder decodeObjectForKey:@"title"] retain];
  descriptionText = [[[NSAttributedString alloc] initWithString:[coder decodeObjectForKey:@"descriptionText"]] retain];
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
  return self;
}

@end

@implementation Event

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle
{
  [self init];
  [self setStartDate:start andConstrain:NO];
  [self setTitle:aTitle];
  [self setDuration:minutes];
  return self;
}

- (void)dealloc
{
  [super dealloc];
  RELEASE(_store);
  RELEASE(_location);
  RELEASE(_externalRef);
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

- (id)externalRef
{
  return _externalRef;
}

- (void)setExternalRef:(id)externalRef
{
  ASSIGN(_externalRef, externalRef);
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
  ASSIGN(startDate, newStartDate);
}

- (void)setStartDate:(Date *)date andConstrain:(BOOL)constrain
{
  [self setStartDate:date];
}

- (void)setEndDate:(Date *)date
{
  ASSIGN(endDate, date);
}

- (void)setInterval:(int)newInterval
{
  interval = newInterval;
}

@end

