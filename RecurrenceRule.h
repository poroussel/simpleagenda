/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import <ical.h>
#import "Date.h"

typedef enum 
{
  /* Simple recurrence rules handled by AppointmentEditor */
  recurrenceFrequenceDaily = 3,
  recurrenceFrequenceWeekly,
  recurrenceFrequenceMonthly,
  recurrenceFrequenceYearly,
  /* Other, more complex, rrules, handled only by libical */
  recurrenceFrequenceOther,
} recurrenceFrequency;

@interface RecurrenceRule : NSObject
{
  struct icalrecurrencetype recur;
}

- (id)initWithFrequency:(recurrenceFrequency)frequency until:(Date *)endDate;
- (id)initWithFrequency:(recurrenceFrequency)frequency count:(int)count;
- (NSEnumerator *)enumeratorFromDate:(Date *)start;
@end

@interface RecurrenceRule(iCalendar)
- (id)initWithICalRRule:(struct icalrecurrencetype)rrule;
- (id)initWithICalString:(NSString *)rrule;
- (struct icalrecurrencetype)iCalRRule;
@end
