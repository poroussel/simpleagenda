#import "RecurrenceRuleTest.h"
#import "../RecurrenceRule.h"

@implementation RecurrenceRuleTest

- (void)testYearlyCount
{
  int count = 0;
  Date *tmp;
  NSEnumerator *enumerator;
  RecurrenceRule *rule = [[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceYearly count:3];

  enumerator = [rule enumeratorFromDate:[Date today]];
  while ((tmp = [enumerator nextObject])) {
    count++;
    [self assertTrue:[tmp isDate] message:@"Recurrence enumerators return dates."];
  }
  [self assertInt:count equals:3 message:@"Iterator should return only 3 dates."];
  [rule release];
}
@end
