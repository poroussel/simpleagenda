/* emacs buffer mode hint -*- objc -*- */

/*
 * Conversions between Date and libical times. Private : only for
 * ICalComponent.m, RecurrenceRule.m and the tests.
 */

#import "config.h"
#import "Date.h"

@interface Date(iCalendar)
- (id)initWithICalTime:(struct icaltimetype)time;
- (struct icaltimetype)UTCICalTime;
- (struct icaltimetype)localICalTime;
@end
