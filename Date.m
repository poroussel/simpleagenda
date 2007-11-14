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
  /* Conversion from ChronographerSource Date format */
  if ([coder containsValueForKey:@"year"]) {
    int minute = abs([coder decodeIntForKey:@"minute"]);
    _time = icaltime_null_time();
    _time.year = [coder decodeIntForKey:@"year"];
    _time.month = [coder decodeIntForKey:@"month"];
    _time.day = [coder decodeIntForKey:@"day"];
    _time.hour = minute / 60;
    _time.minute = minute % 60;
    _time = icaltime_normalize(_time);
    icaltimezone *tz = icaltimezone_get_builtin_timezone([[[NSTimeZone localTimeZone] description] cString]);
    _time = icaltime_set_timezone(&_time, tz);    
  } else {
    NSString *icalTime = [coder decodeObjectForKey:@"icalTime"];
    _time = icaltime_from_string([icalTime cString]);
  }
  return self;
}
@end

/*
 * Based on ChronographerSource Appointment class
 */

@implementation Date
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

- (NSComparisonResult)compareTime:(id)aDate
{
  return icaltime_compare(_time, ((Date *)aDate)->_time);
}

- (NSString *)description
{
  return [NSString stringWithCString:icaltime_as_ical_string(_time)];
}

- (id)initWithTime:(BOOL)time
{
  const char *tzone;
  icaltimezone *tz, *utc;

  self = [super init];
  if (self) {
    tzone = [[[[NSCalendarDate calendarDate] timeZone] description] cString];
    tz = icaltimezone_get_builtin_timezone(tzone);
    utc = icaltimezone_get_utc_timezone();
    if (time)
      _time = icaltime_current_time_with_zone(NULL);
    else
      _time = icaltime_today();
    icaltimezone_convert_time(&_time, utc, tz);
  }
  return self;
}
- (id)init
{
  return [self initWithTime:YES];
}
+ (id)now
{
  return AUTORELEASE([[Date alloc] initWithTime:YES]);
}
+ (id)today
{
  return AUTORELEASE([[Date alloc] initWithTime:NO]);
}

- (NSCalendarDate *)calendarDate
{
  NSCalendarDate *cd = [NSCalendarDate dateWithYear:_time.year 
				       month:_time.month
				       day:_time.day
				       hour:_time.hour
				       minute:_time.minute
				       second:_time.second
				       timeZone:nil];
  return cd;
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

/* 0 = sunday */
- (int)weekday
{
  return icaltime_day_of_week(_time) - 1;
}

- (int)weekOfYear
{
  return icaltime_week_number(_time);
}

- (int)numberOfDaysInMonth
{
  return icaltime_days_in_month(_time.month, _time.year);
}

/* if diff is 23, returns 0 day */
- (int)daysUntil:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(date->_time, _time);
  if (dt.is_neg)
    return -dt.days;
  return dt.days;
}

- (int)daysSince:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(_time, date->_time);
  if (dt.is_neg)
    return -dt.days;
  return dt.days;
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

- (void)setMinute:(int)minute
{
  int old = [self minuteOfDay];
  struct icaldurationtype dt = {0, 0, 0, 0, minute - old, 0};
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
  struct icaldurationtype dt = {diff < 0, abs(diff), 0, 0, 0, 0};
  _time = icaltime_add(_time, dt);
}

- (void)changeMinuteBy:(int)diff
{
  struct icaldurationtype dt = {diff < 0, 0, 0, 0, abs(diff), 0};
  _time = icaltime_add(_time, dt);
}

- (NSEnumerator *)enumeratorTo:(Date *)end
{
  id e;
  e = [NSDateEnumerator allocWithZone:NSDefaultMallocZone()];
  e = [e initWithStart:self end:end];
  return AUTORELEASE(e);
}
@end

@implementation Date(iCalendar)
- (id)initWithICalTime:(struct icaltimetype)time
{
  self = [super init];
  if (self)
    [self setDateToICalTime:time];
  return self;
}

- (void)setDateToICalTime:(struct icaltimetype)time
{
  _time = time;
}

- (struct icaltimetype)iCalTime
{
  return _time;
}
@end

