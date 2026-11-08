#import <Foundation/Foundation.h>
#import <string.h>
#import "Event.h"

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
  return RETAIN(new);
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
  RELEASE(_checkedRule);
  RELEASE(_checkedStart);
  [super dealloc];
}

/*
 * Intersection of [start, start + length[ with day, in seconds from the
 * start of the day. Dates are compared in local time (see
 * -[Date timeIntervalSince1970]), so a day always has 86400 seconds.
 * An event without duration (RFC 5545 3.6.1 : a DATE-TIME DTSTART
 * without DTEND nor DURATION) is an instant : it intersects the day it
 * starts on, with an empty range at its start
 */
static BOOL intersectsDay(Date *start, NSTimeInterval length, Date *day, NSRange *range)
{
  NSCAssert([day isDate], @"This method expects a date, not a datetime");
  NSTimeInterval s1 = [start timeIntervalSince1970];
  NSTimeInterval e1 = s1 + length;
  NSTimeInterval s2 = [day timeIntervalSince1970];
  NSTimeInterval e2 = s2 + 86400;
  NSTimeInterval s = MAX(s1, s2);
  NSTimeInterval e = MIN(e1, e2);

  if (length == 0 && s1 >= s2 && s1 < e2) {
    *range = NSMakeRange(s1 - s2, 0);
    return YES;
  }
  if (e <= s) {
    *range = NSMakeRange(0, 0);
    return NO;
  }
  *range = NSMakeRange(s - s2, e - s);
  return YES;
}

/* The first occurrence intersecting day */
- (BOOL)occurrenceOnDay:(Date *)day range:(NSRange *)range
{
  NSEnumerator *enumerator;
  NSTimeInterval length = [self duration] * 60;
  Date *start;

  if (!_rrule)
    return intersectsDay(_startDate, length, day, range);
  /* Don't look again for occurrences of a rule that has none */
  if (![self hasOccurrences]) {
    *range = NSMakeRange(0, 0);
    return NO;
  }
  enumerator = [self occurrenceEnumerator];
  while ((start = [enumerator nextObject])) {
    if (intersectsDay(start, length, day, range))
      return YES;
    if ([start compare:day withTime:NO] > 0)
      break;
  }
  *range = NSMakeRange(0, 0);
  return NO;
}

- (BOOL)isScheduledForDay:(Date *)day
{
  NSRange range;

  return [self occurrenceOnDay:day range:&range];
}

/*
 * Values are in seconds whereas time granularity in
 * all other Event methods is minute.
 * Worth changing ?
 */
- (NSRange)intersectionWithDay:(Date *)day
{
  NSRange range;

  [self occurrenceOnDay:day range:&range];
  return range;
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

- (NSEnumerator *)occurrenceEnumerator
{
  return [_rrule enumeratorFromDate:_startDate];
}

/*
 * Looking for the first occurrence of a rule that matches rarely or never
 * can take a second (finding 2 in findings.md), and the views ask for
 * each day they show : remember the answer. The start date can be
 * changed in place (DayView moves events), so the answer is kept with the
 * rule and a copy of the start it was computed for
 */
- (BOOL)hasOccurrences
{
  if (!_rrule)
    return YES;
  if (_checkedRule != _rrule || _checkedStart == nil
      || [_checkedStart isDate] != [_startDate isDate]
      || [_checkedStart compare:_startDate withTime:YES] != NSOrderedSame) {
    _hasOccurrences = [[self occurrenceEnumerator] nextObject] != nil;
    ASSIGN(_checkedRule, _rrule);
    DESTROY(_checkedStart);
    _checkedStart = [_startDate copy];
  }
  return _hasOccurrences;
}
@end

@implementation Event(iCalendar)
- (id)initWithICalComponent:(ICalComponent *)component
{
  NSTimeInterval duration;
  NSEnumerator *enumerator;
  NSString *sticky;
  Date *date;

  self = [super initWithICalComponent:component];
  if (self == nil)
    return nil;

  if (![component hasProperty:@"DTSTART"]) {
    NSLog(@"No start date");
    goto init_error;
  }
  date = [component dateForProperty:@"DTSTART"];
  [self setStartDate:date];
  if ([date isDate])
    [self setAllDay:YES];
  else if ([component hasProperty:@"DTEND"])
    [self setDuration:(int)[component secondsFromProperty:@"DTSTART" toProperty:@"DTEND"] / 60];
  else if ([component getDuration:&duration forProperty:@"DURATION"])
    [self setDuration:(int)duration / 60];
  else
    /* RFC 5545 3.6.1 : it ends at its start */
    [self setDuration:0];
  _rrule = RETAIN([component ruleForProperty:@"RRULE"]);
  [self setLocation:[component textForProperty:@"LOCATION"]];
  enumerator = [[component textsForProperty:@"X-SIMPLEAGENDA-STICKY"] objectEnumerator];
  while ((sticky = [enumerator nextObject]))
    [self setSticky:[sticky isEqualToString:@"TRUE"]];
  return self;

 init_error:
  NSLog(@"Error creating Event from iCal component");
  [self release];
  return nil;
}

- (BOOL)updateICalComponent:(ICalComponent *)component
{
  Date *end;

  if (![super updateICalComponent:component])
    return NO;

  [component setText:[self location] forProperty:@"LOCATION"];
  [component setDate:_startDate forProperty:@"DTSTART"];

  /* The -set... methods replace the first DTEND */
  [component removeProperty:@"DURATION"];
  /* Without DTEND nor DURATION, an event ends at its start (RFC 5545 3.6.1) */
  if (![self allDay] && _duration != 0)
    [component setDate:_startDate plusSeconds:_duration * 60 forProperty:@"DTEND"];
  else if ([self allDay]) {
    end = [_startDate copy];
    [end incrementDay];
    [component setDate:end forProperty:@"DTEND"];
    [end release];
    /* OGo workaround ? */
    [component removeAllProperties:@"X-MICROSOFT-CDO-ALLDAYEVENT"];
    [component setText:@"TRUE" forProperty:@"X-MICROSOFT-CDO-ALLDAYEVENT"];
  } else
    [component removeProperty:@"DTEND"];

  [component removeAllProperties:@"X-SIMPLEAGENDA-STICKY"];
  if ([self sticky])
    [component setText:@"TRUE" forProperty:@"X-SIMPLEAGENDA-STICKY"];

  [component setRule:_rrule forProperty:@"RRULE"];
  return YES;
}

- (ICalComponentKind)iCalComponentKind
{
  return ICalVEvent;
}
@end
