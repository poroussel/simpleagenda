/* -*- objc -*- */

#import "ObjectTesting.h"
#import "RecurrenceRule.h"

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  int count = 0;
  Date *tmp;
  NSEnumerator *enumerator;

  test_alloc(@"RecurrenceRule");

  RecurrenceRule *rule = [[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceYearly count:3];

  enumerator = [rule enumeratorFromDate:[Date today]];
  while ((tmp = [enumerator nextObject])) {
    count++;
    PASS([tmp isDate], "Recurrence enumerators return dates.");
  }
  PASS(count == 3, "Iterator should return only 3 dates.");

  test_NSObject(@"RecurrenceRule", [NSArray arrayWithObject:rule]);
  /* FIXME: Also test NSCoding when the code is fixed to pass the test.  */

  [rule release];

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
