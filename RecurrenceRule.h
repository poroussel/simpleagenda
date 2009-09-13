/* emacs buffer mode hint -*- objc -*- */

#import "config.h"
#import <Foundation/Foundation.h>
#ifdef HAVE_LIBICAL_ICAL_H
#import <libical/ical.h>
#else
#import <ical.h>
#endif
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

- (id)initWithFrequency:(recurrenceFrequency)frequency;
- (id)initWithFrequency:(recurrenceFrequency)frequency until:(Date *)endDate;
- (id)initWithFrequency:(recurrenceFrequency)frequency count:(int)count;
- (NSEnumerator *)enumeratorFromDate:(Date *)start;
- (NSEnumerator *)enumeratorFromDate:(Date *)start length:(NSTimeInterval)length;
- (recurrenceFrequency)frequency;
- (Date *)until;
- (int)count;
@end

@interface RecurrenceRule(iCalendar)
- (id)initWithICalRRule:(struct icalrecurrencetype)rrule;
- (id)initWithICalString:(NSString *)rrule;
- (struct icalrecurrencetype)iCalRRule;
@end
