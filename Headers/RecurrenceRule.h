/* emacs buffer mode hint -*- objc -*- */

#import "config.h"
#import <Foundation/Foundation.h>
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
/*
 * The occurrences from start. Empty for a rule that never matches, only
 * start for a rule that isn't expanded (see -isExpandable)
 */
- (NSEnumerator *)enumeratorFromDate:(Date *)start;
/* YES when the rule can't match any day (detected without libical) */
- (BOOL)neverMatches;
/* NO for rules repeating every second or minute, or every hour on some days */
- (BOOL)isExpandable;
- (recurrenceFrequency)frequency;
- (Date *)until;
- (int)count;
@end

@interface RecurrenceRule(iCalendar)
- (id)initWithICalRRule:(struct icalrecurrencetype)rrule;
/*
 * The rscale of the returned rule belongs to the receiver : it is only
 * valid as long as the receiver is
 */
- (struct icalrecurrencetype)iCalRRule;
@end
