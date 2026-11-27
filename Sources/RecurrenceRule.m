#import <stdlib.h>
#import <string.h>
#import "RecurrenceRule.h"

/*
 * The iterator may use the rule (libical 3 keeps a copy of it, rscale
 * pointer included) : the enumerator retains the rule, which owns it
 */
@interface DateRecurrenceEnumerator : NSEnumerator
{
  RecurrenceRule *_rule;
  icalrecur_iterator *_iterator;
}
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start;
@end
@implementation DateRecurrenceEnumerator
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start;
{
  if ((self = [super init])) {
    _rule = RETAIN(rule);
    _iterator = sa_recur_iterator_new([rule iCalRRule], [start localICalTime]);
  }
  return self;
}
- (id)nextObject
{
  struct icaltimetype next;

  next = icalrecur_iterator_next(_iterator);
  if (icaltime_is_null_time(next))
    return nil;
  return AUTORELEASE([[Date alloc] initWithICalTime:next]);
}
- (void)dealloc
{
  icalrecur_iterator_free(_iterator);
  RELEASE(_rule);
  [super dealloc];
}
@end

@implementation RecurrenceRule
- (id)init
{
  self = [super init];
  if (self)
    recur = sa_recur_new();
  return self;
}
- (id)initWithFrequency:(recurrenceFrequency)frequency
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  if ((self = [self init]))
    recur->freq = (icalrecurrencetype_frequency)frequency;
  return self;
}
- (id)initWithFrequency:(recurrenceFrequency)frequency until:(Date *)endDate
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  NSAssert([endDate isDate], @"Works on dates");
  if ((self = [self init])) {
    /*
     * It's OK to use Date iCaltime: here as timezone modifications
     * only affect datetimes, not dates
     */
    recur->until = [endDate UTCICalTime];
    recur->freq = (icalrecurrencetype_frequency)frequency;
  }
  return self;
}
- (id)initWithFrequency:(recurrenceFrequency)frequency count:(int)count
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  if ((self = [self init])) {
    recur->count = count;
    recur->freq = (icalrecurrencetype_frequency)frequency;
  }
  return self;
}
/*
 * libical looks for the next occurrence by testing each day, hour,
 * minute or second up to the year 2582 : a rule that never matches costs
 * up to seconds (finding 2 in findings.md). Detect rules that can't
 * match without asking libical, for the Gregorian calendar only :
 *
 * - MONTHLY with BYSETPOS : libical applies BYSETPOS to the days of the
 *   month only (BYHOUR doesn't multiply the set). They come from
 *   BYMONTHDAY, or else BYDAY (5 per weekday, 1 per numbered weekday),
 *   or else the day of DTSTART. Positions beyond that never match.
 * - BYMONTHDAY values that none of the BYMONTH months have (the 30th
 *   of february).
 */
- (BOOL)neverMatches
{
  static const int daysInMonth[] = {0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
  int nsetpos = sa_recur_by_count(recur, ICAL_BY_SET_POS);
  int nmonthday = sa_recur_by_count(recur, ICAL_BY_MONTH_DAY);
  int nmonth = sa_recur_by_count(recur, ICAL_BY_MONTH);
  int i;

  if (recur->rscale)
    return NO;
  if (recur->freq == ICAL_MONTHLY_RECURRENCE && nsetpos > 0
      && sa_recur_by_count(recur, ICAL_BY_YEAR_DAY) == 0
      && sa_recur_by_count(recur, ICAL_BY_WEEK_NO) == 0) {
    int ndays = 0;
    int nday = sa_recur_by_count(recur, ICAL_BY_DAY);

    if (nmonthday > 0)
      ndays = nmonthday;
    else if (nday > 0)
      for (i = 0; i < nday; i++)
	ndays += icalrecurrencetype_day_position(sa_recur_by_value(recur, ICAL_BY_DAY, i)) ? 1 : 5;
    else
      ndays = 1;
    for (i = 0; i < nsetpos; i++)
      if (abs(sa_recur_by_value(recur, ICAL_BY_SET_POS, i)) <= ndays)
	break;
    if (i == nsetpos)
      return YES;
  }
  if (nmonth > 0 && nmonthday > 0) {
    int maxdays = 0;

    for (i = 0; i < nmonth; i++) {
      int month = icalrecurrencetype_month_month(sa_recur_by_value(recur, ICAL_BY_MONTH, i));
      if (month < 1 || month > 12)
	return NO;
      maxdays = MAX(maxdays, daysInMonth[month]);
    }
    for (i = 0; i < nmonthday; i++)
      if (abs(sa_recur_by_value(recur, ICAL_BY_MONTH_DAY, i)) <= maxdays)
	break;
    if (i == nmonthday)
      return YES;
  }
  return NO;
}

/*
 * Rules repeating every second or minute, or every hour on some days
 * only, can take seconds to minutes to expand, and the views couldn't
 * show them anyway. SimpleAgenda can't create them : such events are
 * shown once, at their start
 */
- (BOOL)isExpandable
{
  if (recur->freq == ICAL_SECONDLY_RECURRENCE || recur->freq == ICAL_MINUTELY_RECURRENCE)
    return NO;
  if (recur->freq == ICAL_HOURLY_RECURRENCE
      && (sa_recur_by_count(recur, ICAL_BY_MONTH) > 0
	  || sa_recur_by_count(recur, ICAL_BY_WEEK_NO) > 0
	  || sa_recur_by_count(recur, ICAL_BY_YEAR_DAY) > 0
	  || sa_recur_by_count(recur, ICAL_BY_MONTH_DAY) > 0))
    return NO;
  return YES;
}

/* start is a date or a datetime, and so are the occurrences */
- (NSEnumerator *)enumeratorFromDate:(Date *)start
{
  if ([self neverMatches])
    return [[NSArray array] objectEnumerator];
  if (![self isExpandable]) {
    Date *until = [self until];
    BOOL ended;

    if (until == nil)
      ended = NO;
    else if ([until isDate] || [start isDate])
      ended = [start compare:until withTime:NO] > 0;
    else
      ended = [start compare:until withTime:YES] > 0;
    if (ended)
      return [[NSArray array] objectEnumerator];
    return [[NSArray arrayWithObject:AUTORELEASE([start copy])] objectEnumerator];
  }
  return AUTORELEASE([[DateRecurrenceEnumerator alloc] initWithRule:self start:start]);
}
- (recurrenceFrequency)frequency
{
  return (recurrenceFrequency)recur->freq;
}
- (Date *)until
{
  if (icaltime_is_null_time(recur->until))
    return nil;
  return AUTORELEASE([[Date alloc] initWithICalTime:recur->until]);
}
- (int)count
{
  return recur->count;
}
- (void)dealloc
{
  sa_recur_free(recur);
  [super dealloc];
}
@end

@implementation RecurrenceRule(iCalendar)
- (id)initWithICalRRule:(const struct icalrecurrencetype *)rrule
{
  if ((self = [super init])) {
    recur = sa_recur_copy(rrule);
    if (recur == NULL) {
      [self release];
      return nil;
    }
  }
  return self;
}
- (id)initWithICalProperty:(icalproperty *)prop
{
  if ((self = [super init])) {
    recur = sa_recur_from_property(prop);
    if (recur == NULL) {
      [self release];
      return nil;
    }
  }
  return self;
}
- (const struct icalrecurrencetype *)iCalRRule
{
  return recur;
}
- (icalproperty *)asICalProperty
{
  return sa_recur_new_property(recur);
}
@end

@implementation RecurrenceRule(NSCoding)
- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:[NSString stringWithCString:icalrecurrencetype_as_string(recur)] forKey:@"rrule"];
}
- (id)initWithCoder:(NSCoder *)coder
{
  if ((self = [super init])) {
    recur = sa_recur_from_string([[coder decodeObjectForKey:@"rrule"] cString]);
    /* An invalid rule : libical 3 used to return an empty one */
    if (recur == NULL)
      recur = sa_recur_new();
  }
  return self;
}
@end
