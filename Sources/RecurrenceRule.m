#import <stdlib.h>
#import <string.h>
#import "RecurrenceRule+ICal.h"
#import "Date+ICal.h"

/*
 * The iterator keeps a copy of the rule, rscale pointer included :
 * the enumerator retains the rule, which owns rscale
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
    _iterator = icalrecur_iterator_new([rule iCalRRule],  [start localICalTime]);
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
  if (self) {
    _recur = malloc(sizeof(*_recur));
    icalrecurrencetype_clear(_recur);
  }
  return self;
}
- (id)initWithFrequency:(recurrenceFrequency)frequency
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  if ((self = [self init]))
    _recur->freq = (icalrecurrencetype_frequency)frequency;
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
    _recur->until = [endDate UTCICalTime];
    _recur->freq = (icalrecurrencetype_frequency)frequency;
  }
  return self;
}
- (id)initWithFrequency:(recurrenceFrequency)frequency count:(int)count
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  if ((self = [self init])) {
    _recur->count = count;
    _recur->freq = (icalrecurrencetype_frequency)frequency;
  }
  return self;
}
/* Number of values in a libical BY array */
static int countOf(const short *array, int size)
{
  int n = 0;

  while (n < size && array[n] != ICAL_RECURRENCE_ARRAY_MAX)
    n++;
  return n;
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
  int nsetpos = countOf(_recur->by_set_pos, ICAL_BY_SETPOS_SIZE);
  int nmonthday = countOf(_recur->by_month_day, ICAL_BY_MONTHDAY_SIZE);
  int nmonth = countOf(_recur->by_month, ICAL_BY_MONTH_SIZE);
  int i;

  if (_recur->rscale)
    return NO;
  if (_recur->freq == ICAL_MONTHLY_RECURRENCE && nsetpos > 0
      && countOf(_recur->by_year_day, ICAL_BY_YEARDAY_SIZE) == 0
      && countOf(_recur->by_week_no, ICAL_BY_WEEKNO_SIZE) == 0) {
    int ndays = 0;
    int nday = countOf(_recur->by_day, ICAL_BY_DAY_SIZE);

    if (nmonthday > 0)
      ndays = nmonthday;
    else if (nday > 0)
      for (i = 0; i < nday; i++)
	ndays += icalrecurrencetype_day_position(_recur->by_day[i]) ? 1 : 5;
    else
      ndays = 1;
    for (i = 0; i < nsetpos; i++)
      if (abs(_recur->by_set_pos[i]) <= ndays)
	break;
    if (i == nsetpos)
      return YES;
  }
  if (nmonth > 0 && nmonthday > 0) {
    int maxdays = 0;

    for (i = 0; i < nmonth; i++) {
      int month = icalrecurrencetype_month_month(_recur->by_month[i]);
      if (month < 1 || month > 12)
	return NO;
      maxdays = MAX(maxdays, daysInMonth[month]);
    }
    for (i = 0; i < nmonthday; i++)
      if (abs(_recur->by_month_day[i]) <= maxdays)
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
  if (_recur->freq == ICAL_SECONDLY_RECURRENCE || _recur->freq == ICAL_MINUTELY_RECURRENCE)
    return NO;
  if (_recur->freq == ICAL_HOURLY_RECURRENCE
      && (countOf(_recur->by_month, ICAL_BY_MONTH_SIZE) > 0
	  || countOf(_recur->by_week_no, ICAL_BY_WEEKNO_SIZE) > 0
	  || countOf(_recur->by_year_day, ICAL_BY_YEARDAY_SIZE) > 0
	  || countOf(_recur->by_month_day, ICAL_BY_MONTHDAY_SIZE) > 0))
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
  return (recurrenceFrequency)_recur->freq;
}
- (Date *)until
{
  if (icaltime_is_null_time(_recur->until))
    return nil;
  return AUTORELEASE([[Date alloc] initWithICalTime:_recur->until]);
}
- (int)count
{
  return _recur->count;
}
- (id)initWithString:(NSString *)string
{
  if ((self = [super init])) {
    _recur = malloc(sizeof(*_recur));
    /* icalrecurrencetype_from_string() allocates rscale, freed by -dealloc */
    if (string)
      *_recur = icalrecurrencetype_from_string([string UTF8String]);
    else
      icalrecurrencetype_clear(_recur);
  }
  return self;
}
- (NSString *)stringValue
{
  char *string = icalrecurrencetype_as_string(_recur);

  return string ? [NSString stringWithUTF8String:string] : nil;
}
- (void)dealloc
{
  if (_recur) {
    free(_recur->rscale);
    free(_recur);
  }
  [super dealloc];
}
@end

@implementation RecurrenceRule(iCalendar)
- (id)initWithICalRRule:(struct icalrecurrencetype)rrule
{
  if ((self = [super init])) {
    _recur = malloc(sizeof(*_recur));
    *_recur = rrule;
    /* rrule.rscale belongs to the property it comes from */
    if (rrule.rscale)
      _recur->rscale = strdup(rrule.rscale);
  }
  return self;
}
- (struct icalrecurrencetype)iCalRRule
{
  return *_recur;
}
@end

@implementation RecurrenceRule(NSCoding)
- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:[NSString stringWithCString:icalrecurrencetype_as_string(_recur)] forKey:@"rrule"];
}
/* icalrecurrencetype_from_string() allocates rscale, freed by -dealloc */
- (id)initWithCoder:(NSCoder *)coder
{
  _recur = malloc(sizeof(*_recur));
  *_recur = icalrecurrencetype_from_string([[coder decodeObjectForKey:@"rrule"] cString]);
  return self;
}
@end
