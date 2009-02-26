#import "Date.h"

@interface NSDateEnumerator : NSEnumerator
{
  Date *_start;
  Date *_end;
}
- (id)initWithStart:(Date *)start end:(Date *)end;
@end
@implementation NSDateEnumerator
- (id)initWithStart:(Date *)start end:(Date *)end
{
  self = [super init];
  if (self != nil) {
    _start = [start copy];
    _end = [end copy];
    [_start setDate:YES];
    [_end setDate:YES];
    [_start changeDayBy:-1];
  }
  return self;
}
- (id)nextObject
{
  [_start incrementDay];
  if ([_start daysUntil:_end] < 0)
    return nil;
  return _start;
}
- (void)dealloc
{
  [_start release];
  [_end release];
  [super dealloc];
}
@end

@implementation Date(NSCoding)
- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:[NSString stringWithCString:icaltime_as_ical_string(_time)] forKey:@"icalTime"];
}
- (id)initWithCoder:(NSCoder *)coder
{
  _time = icaltime_from_string([[coder decodeObjectForKey:@"icalTime"] cString]);
  return self;
}
@end

/*
 * Based on ChronographerSource Appointment class
 */

@implementation Date
static icaltimezone *gl_tz = NULL;
static icaltimezone *gl_utc = NULL;
static NSTimeZone *gl_nstz = nil;
+ (void)initialize
{
  const char *tzone;

  if (!gl_tz) {
    gl_nstz = RETAIN([[NSCalendarDate calendarDate] timeZone]);
    tzone = [[gl_nstz description] cString];
    gl_utc = icaltimezone_get_utc_timezone();
    gl_tz = icaltimezone_get_builtin_timezone(tzone);
    if (!gl_tz)
      NSLog(@"Couldn't get a timezone corresponding to %s", tzone);
  }
}

- (id)copyWithZone:(NSZone *)zone
{
  Date *new = [Date allocWithZone:zone];
  new->_time = _time;
  return new;
}

- (NSComparisonResult)compare:(id)aDate
{
  return icaltime_compare_date_only(_time, ((Date *)aDate)->_time);
}

/*
 * This is a bit convoluted because icaltime_compare
 * create to dates in utc timezone to do the comparison.
 * The conversion to utc means a datetime will be modified
 * (up or down, depending on the local time zone) and a
 * date won't.
 */
- (NSComparisonResult)compareTime:(id)aDate
{
  NSComparisonResult res;
  int a_isdate = _time.is_date;
  int b_isdate = ((Date *)aDate)->_time.is_date;
  _time.is_date = 0;
  ((Date *)aDate)->_time.is_date = 0;
  res = icaltime_compare(_time, ((Date *)aDate)->_time);
  _time.is_date = a_isdate;
  ((Date *)aDate)->_time.is_date = b_isdate;
  return res;
}

- (NSString *)description
{
  return [NSString stringWithCString:icaltime_as_ical_string(_time)];
}

- (id)init
{
  self = [super init];
  if (self) {
    _time = icaltime_current_time_with_zone(gl_tz);
    _time = icaltime_set_timezone(&_time, gl_tz);
  }
  return self;
}
- (id)initWithCalendarDate:(NSCalendarDate *)cd withTime:(BOOL)time
{
  self = [self init];
  if (self) {
    _time.is_date = !time;
    _time.year = [cd yearOfCommonEra];
    _time.month = [cd monthOfYear];
    _time.day = [cd dayOfMonth];
    if (time) {
      _time.hour = [cd hourOfDay];
      _time.minute = [cd minuteOfHour];
      _time.second = [cd secondOfMinute];
    } else {
      _time.hour = 0;
      _time.minute = 0;
      _time.second = 0;
    }
    /* FIXME : use NSCalendarDate Timezone ? */
  }
  return self;
}
- (id)initWithTimeInterval:(NSTimeInterval)seconds sinceDate:(Date *)refDate
{
  self = [super init];
  if (self) {
    _time = refDate->_time;
    /* To be able to add hours and minutes, it has to be a datetime */
    _time.is_date = 0;
    _time = icaltime_add(_time, icaldurationtype_from_int(seconds));
  }
  return self;
}
+ (id)now
{
  return AUTORELEASE([[Date alloc] init]);
}
+ (id)today
{
  Date *d = [[Date alloc] init];
  [d setDate:YES];
  return AUTORELEASE(d);
}

- (NSCalendarDate *)calendarDate
{
  return [NSCalendarDate dateWithYear:_time.year 
			 month:_time.month
			 day:_time.day
			 hour:_time.hour
			 minute:_time.minute
			 second:_time.second
			 timeZone:gl_nstz];
}

- (int)year
{
  return _time.year;
}
- (int)monthOfYear
{
  return _time.month;
}
- (int)hourOfDay
{
  return _time.hour;
}
- (int)secondOfMinute
{
  return _time.second;
}
- (int)minuteOfHour
{
  return _time.minute;
}
- (int)minuteOfDay
{
  return _time.hour * 60 + _time.minute;
}
- (int)dayOfMonth
{
  return _time.day;
}
/*
 * 1 : Monday
 * ...
 * 7 : Sunday
 */
- (int)weekday
{
  int dow = icaltime_day_of_week(_time) - 1;
  return dow ? dow : 7;
}
- (int)weekOfYear
{
  char week[3];
  time_t tmt = icaltime_as_timet(_time);
  struct tm *tm = gmtime(&tmt);
  strftime(week, sizeof(week), "%V", tm);
  return atoi(week);
}
- (int)numberOfDaysInMonth
{
  return icaltime_days_in_month(_time.month, _time.year);
}

- (int)daysUntil:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(date->_time, _time);
  return icaldurationtype_as_int(dt) / 86400;
}

- (int)daysSince:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(_time, date->_time);
  return icaldurationtype_as_int(dt) / 86400;
}

- (int)weeksUntil:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(date->_time, _time);
  if (dt.is_neg)
    return -dt.weeks;
  return dt.weeks;
}

- (int)weeksSince:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(_time, date->_time);
  if (dt.is_neg)
    return -dt.weeks;
  return dt.weeks;
}

- (int)monthsUntil:(Date *)date
{
  int months = 0;
  NSLog(@"monthsUntil");
  return months;
}

- (int)monthsSince:(Date *)date
{
  int months = 0;
  NSLog(@"monthsSince");
  return months;
}

- (int)yearsUntil:(Date *)date
{
  return date->_time.year - _time.year;
}

- (int)yearSince:(Date *)date
{
  return _time.year - date->_time.year;
}

- (void)clearTime
{
  _time.hour = 0;
  _time.minute = 0;
  _time.second = 0;
}

- (void)setSecondOfMinute:(int)second
{
  [self setDate:NO];
  _time.second = second;
  _time = icaltime_normalize(_time);
}

- (void)setMinute:(int)minute
{
  [self setDate:NO];
  struct icaldurationtype dt = {0, 0, 0, 0, minute - [self minuteOfDay], 0};
  _time = icaltime_add(_time, dt);
}

- (void)setDay:(int)day
{
  _time.day = day;
  _time = icaltime_normalize(_time);
}

- (void)setMonth:(int)month
{
  _time.month = month;
  _time = icaltime_normalize(_time);
}

- (void)setYear:(int)year
{
  _time.year = year;
}

- (void)incrementDay
{
  struct icaldurationtype dt = {0, 1, 0, 0, 0, 0};
  _time = icaltime_add(_time, dt);
}

- (void)changeYearBy:(int)diff
{
  _time.year += diff;
}

- (void)changeDayBy:(int)diff
{
  struct icaldurationtype dt = {diff < 0, ABS(diff), 0, 0, 0, 0};
  _time = icaltime_add(_time, dt);
}

- (void)changeMinuteBy:(int)diff
{
  struct icaldurationtype dt = {diff < 0, 0, 0, 0, ABS(diff), 0};
  _time = icaltime_add(_time, dt);
}

- (NSEnumerator *)enumeratorTo:(Date *)end
{
  id e;
  e = [NSDateEnumerator allocWithZone:NSDefaultMallocZone()];
  e = [e initWithStart:self end:end];
  return AUTORELEASE(e);
}

- (BOOL)isDate
{
  return _time.is_date;
}
- (void)setDate:(BOOL)date
{
  _time.is_date = date;
  if (date) {
    _time.hour = 0;
    _time.minute = 0;
    _time.second = 0;
  }
}

- (NSTimeInterval)timeIntervalSince1970
{
  return icaltime_as_timet(_time);
}

- (NSTimeInterval)timeIntervalSinceDate:(Date *)anotherDate
{
  return icaldurationtype_as_int(icaltime_subtract(_time, anotherDate->_time));
}
@end

/*
 * Dates are stored in the local timezone in memory
 * and in utc in iCalTree. These methods do the
 * necessary conversions
 */
@implementation Date(iCalendar)
- (id)initWithICalTime:(struct icaltimetype)time
{
  self = [super init];
  if (self)
    _time = icaltime_convert_to_zone(time, gl_tz);
  return self;
}
- (struct icaltimetype)iCalTime
{
  return icaltime_convert_to_zone(_time, gl_utc);
}
@end
