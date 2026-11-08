#import "Date+ICal.h"

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
    [_start setIsDate:YES];
    [_end setIsDate:YES];
    [_start changeDayBy:-1];
  }
  return self;
}
- (id)nextObject
{
  [_start incrementDay];
  if ([_end timeIntervalSinceDate:_start] < 0)
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

/* Set by +[Date initialize] */
static icaltimezone *gl_tz = NULL;
static icaltimezone *gl_utc = NULL;
static NSTimeZone *gl_nstz = nil;

/*
 * Date keeps the fields of a struct icaltimetype, so that its header
 * doesn't depend on libical : the methods read them in a struct
 * icaltimetype, and write it back when they change it
 */
#define TIME(date) timeOf(date)
#define SET_TIME(date, time) setTimeOf(date, time)

@interface Date(Fields)
- (struct icaltimetype)fields;
- (void)setFields:(struct icaltimetype)time;
@end

static inline struct icaltimetype timeOf(Date *date)
{
  return [date fields];
}

static inline void setTimeOf(Date *date, struct icaltimetype time)
{
  [date setFields:time];
}

@implementation Date(NSCoding)
- (void)encodeWithCoder:(NSCoder *)coder
{
  struct icaltimetype _time = TIME(self);

  [coder encodeObject:[NSString stringWithCString:icaltime_as_ical_string(_time)] forKey:@"icalTime"];
  /* icaltime_as_ical_string does not include timezone info, so encode it
   * separately to allow faithful restoration on decode. */
  if (_time.zone) {
    const char *tzid = icaltimezone_get_tzid((icaltimezone *)_time.zone);
    if (tzid)
      [coder encodeObject:[NSString stringWithCString:tzid] forKey:@"timezone"];
  }
}
/*
 * -encodeWithCoder: writes the full tzid (/freeassociation.sourceforge.net/
 * Europe/Paris), which icaltimezone_get_builtin_timezone() doesn't know :
 * look it up as a tzid first, then as a location.
 */
static icaltimezone *timezoneNamed(NSString *name)
{
  const char *cname = [name UTF8String];
  icaltimezone *tz;

  if (cname == NULL || *cname == 0)
    return NULL;
  if (!strcmp(cname, "UTC"))
    return icaltimezone_get_utc_timezone();
  tz = icaltimezone_get_builtin_timezone_from_tzid(cname);
  if (tz == NULL)
    tz = icaltimezone_get_builtin_timezone(cname);
  return tz;
}

- (id)initWithCoder:(NSCoder *)coder
{
  NSString *string = [coder decodeObjectForKey:@"icalTime"];
  struct icaltimetype time = icaltime_null_time();
  icaltimezone *tz;

  if ([string isKindOfClass:[NSString class]])
    time = icaltime_from_string([string UTF8String]);
  /* A datetime without Z was written in the timezone stored next to it,
   * or in the local timezone if it can't be found */
  if (!time.is_date && time.zone == NULL && !icaltime_is_null_time(time)) {
    tz = timezoneNamed([coder decodeObjectForKey:@"timezone"]);
    time = icaltime_set_timezone(&time, tz ? tz : gl_tz);
  }
  /* Like dates read from iCalendar data, keep it in the local timezone */
  return [self initWithICalTime:time];
}
@end

/*
 * Based on ChronographerSource Appointment class
 *
 * See Date.h for the limitations with dates before 1902 or more
 * than 68 years apart.
 */

@implementation Date(Fields)
- (struct icaltimetype)fields
{
  struct icaltimetype time;

  time.year = _year;
  time.month = _month;
  time.day = _day;
  time.hour = _hour;
  time.minute = _minute;
  time.second = _second;
  time.is_date = _isDate;
  time.is_daylight = _isDaylight;
  time.zone = _zone;
  return time;
}

- (void)setFields:(struct icaltimetype)time
{
  _year = time.year;
  _month = time.month;
  _day = time.day;
  _hour = time.hour;
  _minute = time.minute;
  _second = time.second;
  _isDate = time.is_date;
  _isDaylight = time.is_daylight;
  _zone = time.zone;
}
@end

@implementation Date
/*
 * GNUstep uses a fixed offset timezone named GMT+0000, GMT+0300... for
 * TZ=UTC or TZ=GMT and when it can't find the system timezone. libical
 * doesn't know these names : use its UTC timezone or its POSIX style
 * Etc/GMT-3 zones (the sign is inverted) for whole hour offsets.
 */
static icaltimezone *fixedOffsetTimezone(NSInteger offset)
{
  char name[16];
  NSInteger hours = offset / 3600;

  if (offset == 0)
    return icaltimezone_get_utc_timezone();
  if (offset % 3600 || hours < -12 || hours > 14)
    return NULL;
  snprintf(name, sizeof(name), "Etc/GMT%+ld", (long)-hours);
  return icaltimezone_get_builtin_timezone(name);
}

+ (void)initialize
{
  const char *tzone;

  if (!gl_tz) {
    gl_nstz = RETAIN([[NSCalendarDate calendarDate] timeZone]);
    tzone = [[gl_nstz name] UTF8String];
    gl_utc = icaltimezone_get_utc_timezone();
    gl_tz = icaltimezone_get_builtin_timezone(tzone);
    if (!gl_tz)
      gl_tz = fixedOffsetTimezone([gl_nstz secondsFromGMT]);
    if (!gl_tz)
      NSLog(@"Couldn't get a timezone corresponding to %s", tzone);
  }
}

- (id)copyWithZone:(NSZone *)zone
{
  Date *new = [Date allocWithZone:zone];
  SET_TIME(new, TIME(self));
  return new;
}

/*
 * This method shouldn't be used as it's not
 * clear if it should compare Dates or DateTimes
 */
- (NSComparisonResult)compare:(id)aDate
{
  [self notImplemented:_cmd];
  return NSOrderedSame;
}

- (BOOL)isEqual:(id)aDate
{
  if (aDate == nil)
    return NO;
  if (aDate == self)
    return YES;
  if (![aDate isKindOfClass:[Date class]])
    return NO;
  return icaltime_as_timet(TIME(self)) == icaltime_as_timet(TIME(aDate));
}

- (NSUInteger)hash
{
  return icaltime_as_timet(TIME(self));
}
/*
 * This is a bit convoluted because icaltime_compare
 * creates two dates in utc timezone to do the comparison.
 * The conversion to utc means a datetime will be modified
 * (up or down, depending on the local time zone) and a
 * date won't.
 */
- (NSComparisonResult)compare:(id)aDate withTime:(BOOL)time
{
  struct icaltimetype _time = TIME(self);
  struct icaltimetype other = TIME(aDate);

  if (!time) {
    if (_time.year < other.year)
      return -1;
    if (_time.year > other.year)
      return 1;
    if (_time.month < other.month)
      return -1;
    if (_time.month > other.month)
      return 1;
    if (_time.day < other.day)
      return -1;
    if (_time.day > other.day)
      return 1;
    return 0;
  }

  /* Dates have no timezone : compare them as local datetimes */
  struct icaltimetype a = _time;
  struct icaltimetype b = other;
  a.is_date = 0;
  b.is_date = 0;
  if (a.zone == NULL)
    a.zone = gl_tz;
  if (b.zone == NULL)
    b.zone = gl_tz;
  return icaltime_compare(a, b);
}

- (NSString *)description
{
  /* The local wall time : without the Z libical adds in its UTC timezone */
  struct icaltimetype local = TIME(self);

  local.zone = NULL;
  return [NSString stringWithCString:icaltime_as_ical_string(local)];
}

- (id)init
{
  self = [super init];
  if (self) {
    struct icaltimetype _time = icaltime_current_time_with_zone(gl_tz);
    _time = icaltime_set_timezone(&_time, gl_tz);
    SET_TIME(self, _time);
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
  [d setIsDate:YES];
  return AUTORELEASE(d);
}

+ (id)dateWithTimeInterval:(NSTimeInterval)seconds sinceDate:(Date *)refDate
{
  Date *d = [[Date alloc] init];
  struct icaltimetype time = TIME(refDate);

  /* To be able to add hours and minutes, it has to be a datetime */
  time.is_date = 0;
  if (time.zone == NULL)
    time.zone = gl_tz;
  time = icaltime_add(time, icaldurationtype_from_int(seconds));
  SET_TIME(d, time);
  [d setIsDate:!time.hour && !time.minute && !time.second];
  return AUTORELEASE(d);
}

+ (id)dateWithCalendarDate:(NSCalendarDate *)cd withTime:(BOOL)time
{
  Date *d = [[Date alloc] init];
  struct icaltimetype t;

  [d setIsDate:!time];
  t = TIME(d);
  t.year = [cd yearOfCommonEra];
  t.month = [cd monthOfYear];
  t.day = [cd dayOfMonth];
  if (time) {
    t.hour = [cd hourOfDay];
    t.minute = [cd minuteOfHour];
    t.second = [cd secondOfMinute];
  } else {
    t.hour = 0;
    t.minute = 0;
    t.second = 0;
  }
  SET_TIME(d, t);
  return AUTORELEASE(d);
}

+ (id)dayWithDate:(Date *)date
{
  Date *d = [date copy];
  [d setIsDate:YES];
  return AUTORELEASE(d);
}

- (NSCalendarDate *)calendarDate
{
  return [NSCalendarDate dateWithYear:_year
			 month:_month
			 day:_day
			 hour:_hour
			 minute:_minute
			 second:_second
			 timeZone:gl_nstz];
}

- (int)year
{
  return _year;
}
- (int)monthOfYear
{
  return _month;
}
- (int)hourOfDay
{
  return _hour;
}
- (int)secondOfMinute
{
  return _second;
}
- (int)minuteOfHour
{
  return _minute;
}
- (int)minuteOfDay
{
  return _hour * 60 + _minute;
}
- (int)dayOfMonth
{
  return _day;
}
/*
 * 1 : Monday
 * ...
 * 7 : Sunday
 */
- (int)weekday
{
  int dow = icaltime_day_of_week(TIME(self)) - 1;
  return dow ? dow : 7;
}
- (int)weekOfYear
{
  char week[3];
  time_t tmt = icaltime_as_timet(TIME(self));
  struct tm *tm = gmtime(&tmt);
  strftime(week, sizeof(week), "%V", tm);
  return atoi(week);
}
- (int)numberOfDaysInMonth
{
  return icaltime_days_in_month(_month, _year);
}

- (void)setSecondOfMinute:(int)second
{
  struct icaltimetype _time = TIME(self);

  NSAssert(!_time.is_date, @"Works only with datetimes");
  _time.second = second;
  SET_TIME(self, icaltime_normalize(_time));
}

- (void)setMinute:(int)minute
{
  struct icaltimetype _time = TIME(self);

  NSAssert(!_time.is_date, @"Works only with datetimes");
  struct icaldurationtype dt = {0, 0, 0, 0, minute - [self minuteOfDay], 0};
  SET_TIME(self, icaltime_add(_time, dt));
}

- (void)setDay:(int)day
{
  struct icaltimetype _time = TIME(self);

  _time.day = day;
  SET_TIME(self, icaltime_normalize(_time));
}

- (void)setMonth:(int)month
{
  struct icaltimetype _time = TIME(self);

  _time.month = month;
  SET_TIME(self, icaltime_normalize(_time));
}

- (void)setYear:(int)year
{
  struct icaltimetype _time = TIME(self);

  _time.year = year;
  SET_TIME(self, icaltime_normalize(_time));
}

- (void)incrementDay
{
  struct icaldurationtype dt = {0, 1, 0, 0, 0, 0};
  SET_TIME(self, icaltime_add(TIME(self), dt));
}

- (void)changeYearBy:(int)diff
{
  struct icaltimetype _time = TIME(self);

  _time.year += diff;
  SET_TIME(self, icaltime_normalize(_time));
}

- (void)changeDayBy:(int)diff
{
  struct icaldurationtype dt = {diff < 0, ABS(diff), 0, 0, 0, 0};
  SET_TIME(self, icaltime_add(TIME(self), dt));
}

- (void)changeMinuteBy:(int)diff
{
  struct icaldurationtype dt = {diff < 0, 0, 0, 0, ABS(diff), 0};
  SET_TIME(self, icaltime_add(TIME(self), dt));
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
  return _isDate;
}
/*
 * A date is a day without time, so without timezone : a timezone would
 * change the occurrences of a sub-daily rule (DST) and isn't archived
 * or exported. A datetime made from a date is in the local timezone
 */
- (void)setIsDate:(BOOL)date
{
  _isDate = date;
  if (date) {
    _hour = 0;
    _minute = 0;
    _second = 0;
    _zone = NULL;
  } else if (_zone == NULL) {
    _zone = gl_tz;
  }
}

- (NSTimeInterval)timeIntervalSince1970
{
  return icaltime_as_timet(TIME(self));
}

- (NSTimeInterval)timeIntervalSinceDate:(Date *)anotherDate
{
  return icaldurationtype_as_int(icaltime_subtract(TIME(self), TIME(anotherDate)));
}

- (NSTimeInterval)timeIntervalSinceNow
{
  return [self timeIntervalSinceDate:[Date now]];
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
  if (self) {
    struct icaltimetype _time = icaltime_convert_to_zone(icaltime_normalize(time), gl_tz);
    /* icaltime_convert_to_zone() keeps the timezone of a date */
    if (_time.is_date)
      _time.zone = NULL;
    SET_TIME(self, _time);
  }
  return self;
}
- (struct icaltimetype)UTCICalTime
{
  return icaltime_convert_to_zone(TIME(self), gl_utc);
}
- (struct icaltimetype)localICalTime
{
  return TIME(self);
}
@end
