#import "Date.h"

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


- (id)init
{
  self = [super init];
  if (self) {
    NSCalendarDate *cd = [NSCalendarDate calendarDate];
    icaltimezone *tz = icaltimezone_get_builtin_timezone([[[cd timeZone] description] cString]);
    _time = icaltime_null_time();
    _time = icaltime_set_timezone(&_time, tz);    
    _time.year = [cd yearOfCommonEra];
    _time.month = [cd monthOfYear];
    _time.day = [cd dayOfMonth];
    _time.hour = [cd hourOfDay];
    _time.minute = [cd minuteOfHour];
  }
  return self;
}

+ (id)date
{
  return AUTORELEASE([[Date alloc] init]);
}

- (NSCalendarDate *)calendarDate
{
  NSCalendarDate *cd = [NSCalendarDate dateWithYear:_time.year 
				       month:_time.month
				       day:_time.day
				       hour:_time.hour
				       minute:_time.minute
				       second:0 
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

- (int)daysUntil:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(_time, date->_time);
  return dt.days;
}

- (int)daysSince:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(date->_time, _time);
  return dt.days;
}

- (int)weeksUntil:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(_time, date->_time);
  return dt.weeks;
}

- (int)weeksSince:(Date *)date
{
  struct icaldurationtype dt;

  dt = icaltime_subtract(date->_time, _time);
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
  int years = 0;
  NSLog(@"yearsUntil");
  return years;
}

- (int)yearSince:(Date *)date
{
  int years = 0;
  NSLog(@"yearSince");
  return years;
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
  struct icaldurationtype dt = {diff < 0, diff, 0, 0, 0, 0};
  _time = icaltime_add(_time, dt);
}

- (void)changeMinuteBy:(int)diff
{
  struct icaldurationtype dt = {diff < 0, 0, 0, 0, diff, 0};
  _time = icaltime_add(_time, dt);
}

@end
