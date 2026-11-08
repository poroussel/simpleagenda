/* emacs buffer mode hint -*- objc -*- */

/*
 * Conversions between RecurrenceRule and libical rules. Private : only
 * for ICalComponent.m and the tests.
 */

#import "config.h"
#import "RecurrenceRule.h"

@interface RecurrenceRule(iCalendar)
- (id)initWithICalRRule:(struct icalrecurrencetype)rrule;
/*
 * The rscale of the returned rule belongs to the receiver : it is only
 * valid as long as the receiver is
 */
- (struct icalrecurrencetype)iCalRRule;
@end
