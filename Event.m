/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "Event.h"

@implementation Date(NSCoding)
-(void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeInt:year forKey:@"year"];
  [coder encodeInt:month forKey:@"month"];
  [coder encodeInt:day forKey:@"day"];
  [coder encodeInt:minute forKey:@"minute"];
}
-(id)initWithCoder:(NSCoder *)coder
{
  [super init];
  year = [coder decodeIntForKey:@"year"];
  month = [coder decodeIntForKey:@"month"];
  day = [coder decodeIntForKey:@"day"];
  minute = [coder decodeIntForKey:@"minute"];
  return self;
}
@end

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

/*
 * Code adapted from ChronographerSource Appointment:isScheduledFor
 * I don't understand the first three lines of their version
 */
- (BOOL)isScheduledForDay:(Date *)day
{
  if (!day || [day daysUntil:startDate] > 0 || [day daysSince:endDate] > 0)
    return NO;
  switch (interval) {
  case RI_NONE:
    return YES;
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

- (id <AgendaStore>)store
{
  return _store;
}

- (void)setStore:(id <AgendaStore>)store
{
  _store = store;
}

- (NSString *)location
{
  return _location;
}

- (void)setLocation:(NSString *)location
{
  _location = location;
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
  return [NSString stringWithFormat:@"<%@> from <%@> for <%d>", [self title], [self startDate], [self duration]];
}

- (void)setDuration:(int)newDuration
{
  [super setDuration:newDuration];
  [self setAllDay:(newDuration == 1440)];
}

@end

