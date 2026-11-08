/* emacs buffer mode hint -*- objc -*- */

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

struct icalrecurrencetype;

@interface RecurrenceRule : NSObject
{
  /* A libical rule, owned by the receiver (see RecurrenceRule+ICal.h) */
  struct icalrecurrencetype *_recur;
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
/* An RRULE value (RFC 5545), and back */
- (id)initWithString:(NSString *)string;
- (NSString *)stringValue;
@end
