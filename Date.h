/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import <ical.h>

@interface Date : NSObject <NSCoding, NSCopying>
{
  struct icaltimetype _time;
}

+ (id)date;

- (NSCalendarDate *)calendarDate;

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
- (void)setDay:(int)minute;
- (void)setMonth:(int)minute;
- (void)setYear:(int)minute;
- (void)incrementDay;
- (void)changeYearBy:(int)diff;
- (void)changeDayBy:(int)diff;
- (void)changeMinuteBy:(int)diff;
@end

@interface Date(iCalendar)
- (id)initWithICalTime:(struct icaltimetype)time;
- (void)setDateToICalTime:(struct icaltimetype)time;
- (struct icaltimetype)iCalTime;
@end

