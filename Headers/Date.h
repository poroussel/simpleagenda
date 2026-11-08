/* emacs buffer mode hint -*- objc -*- */

#import "config.h"
#import <Foundation/Foundation.h>

/*
 * A date (no time, isDate == YES) or a datetime, kept in the local
 * timezone. Dates read from iCalendar data or decoded from an archive
 * are normalized and converted to the local timezone.
 *
 * Known limitations, inherited from libical (3.0) :
 *
 * - Dates before 1902 : icaltime_as_timet() returns -1 for all of them.
 *   -isEqual: and -hash consider them all equal, -timeIntervalSince1970
 *   returns -1, -timeIntervalSinceDate: returns 0 between two of them
 *   (and a wrong value with a later date), -weekOfYear returns 1, and
 *   an enumerator from -enumeratorTo: never ends if both its start and
 *   end dates are before 1902. -[Event intersectionWithDay:] is also
 *   wrong for these dates.
 *
 * - Dates more than 68 years apart : -timeIntervalSinceDate: goes
 *   through icaldurationtype_as_int(), which overflows an int, so the
 *   result is wrong and can have the wrong sign. -timeIntervalSince1970
 *   isn't affected.
 *
 * Comparisons with -compare:withTime: are correct in both cases.
 */
@interface Date : NSObject
{
  struct icaltimetype _time;
}

+ (id)now;
+ (id)today;
+ (id)dateWithTimeInterval:(NSTimeInterval)seconds sinceDate:(Date *)refDate;
+ (id)dateWithCalendarDate:(NSCalendarDate *)cd withTime:(BOOL)time;
+ (id)dayWithDate:(Date *)date;
- (NSCalendarDate *)calendarDate;
- (NSComparisonResult)compare:(id)aTime withTime:(BOOL)time;
- (int)year;
- (int)monthOfYear;
- (int)hourOfDay;
- (int)secondOfMinute;
- (int)minuteOfHour;
- (int)minuteOfDay;
- (int)dayOfMonth;
- (int)weekday;
- (int)weekOfYear;
- (int)numberOfDaysInMonth;
- (void)setSecondOfMinute:(int)second;
- (void)setMinute:(int)minute;
- (void)setDay:(int)day;
- (void)setMonth:(int)month;
- (void)setYear:(int)year;
- (void)incrementDay;
- (void)changeYearBy:(int)diff;
- (void)changeDayBy:(int)diff;
- (void)changeMinuteBy:(int)diff;
- (NSEnumerator *)enumeratorTo:(Date *)end;
- (BOOL)isDate;
- (void)setIsDate:(BOOL)date;
- (NSTimeInterval)timeIntervalSince1970;
- (NSTimeInterval)timeIntervalSinceDate:(Date *)anotherDate;
- (NSTimeInterval)timeIntervalSinceNow;
@end

@interface Date(iCalendar)
- (id)initWithICalTime:(struct icaltimetype)time;
- (struct icaltimetype)UTCICalTime;
- (struct icaltimetype)localICalTime;
@end

/* The time of a property, in the timezone given by its TZID parameter :
   a VTIMEZONE of its calendar or a zone known by libical. Without TZID,
   or with an unknown one, the time is returned unchanged */
struct icaltimetype icaltimeWithTZID(icalproperty *prop, struct icaltimetype time);
