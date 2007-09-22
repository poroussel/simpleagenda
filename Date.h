/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import <ical.h>

@interface Date : NSObject
{
  struct icaltimetype _time;
}

+ (id)date;

- (NSCalendarDate *)calendarDate;
- (NSComparisonResult)compare:(id)aDate;
- (NSComparisonResult)compareTime:(id)aTime;
- (int)year;
- (int)monthOfYear;
- (int)hourOfDay;
- (int)minuteOfHour;
- (int)minuteOfDay;
- (int)dayOfMonth;
- (int)weekday;
- (int)weekOfYear;
- (int)numberOfDaysInMonth;
- (int)daysUntil:(Date *)date;
- (int)daysSince:(Date *)date;
- (int)weeksUntil:(Date *)date;
- (int)weeksSince:(Date *)date;
- (int)monthsUntil:(Date *)date;
- (int)monthsSince:(Date *)date;
- (int)yearsUntil:(Date *)date;
- (int)yearSince:(Date *)date;
- (void)setMinute:(int)minute;
- (void)setDay:(int)day;
- (void)setMonth:(int)month;
- (void)setYear:(int)year;
- (void)incrementDay;
- (void)changeYearBy:(int)diff;
- (void)changeDayBy:(int)diff;
- (void)changeMinuteBy:(int)diff;
- (NSEnumerator *)enumeratorTo:(Date *)end;
@end

@interface Date(iCalendar)
- (id)initWithICalTime:(struct icaltimetype)time;
- (void)setDateToICalTime:(struct icaltimetype)time;
- (struct icaltimetype)iCalTime;
@end

