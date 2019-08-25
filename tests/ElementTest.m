/* -*- objc -*- */

#import "ObjectTesting.h"
#import "MemoryStore.h"
#import "Element.h"
#import "Date.h"
#import "Alarm.h"

@implementation Element(Testing)
/* For the purpose of testing, consider two instances of the Element
   class equal if the ivars of the decoded object are the same as the
   ivars of the encoded one.  */
- (BOOL) isEqualForTestcase:(id)other
{
  NSUInteger i;

  if (other == nil || [other isKindOfClass:[Element class]] == NO)
    return NO;
  if ([[self summary] isEqualToString:[other summary]] == NO)
    return NO;
  if ([[self alarms] count] != [[other alarms] count])
    return NO;
  for (i = 0; i < [[self alarms] count]; i++)
    if ([[[[self alarms] objectAtIndex:i] description]
	  isEqualToString:[[[other alarms] objectAtIndex:i] description]] == NO)
      return NO;
  if ([[[self text] string] isEqualToString:[[other text] string]] == NO)
    return NO;
  if ([self classification] != [other classification])
    return NO;
  if ([[self dateStamp] isEqual:[other dateStamp]] == NO)
    return NO;
  if ([[self categories] isEqualToArray:[other categories]] == NO)
      return NO;
  return YES;
}
@end

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  Element *e1, *e2, *e3;
  Alarm *al1, *al2;

  test_alloc(@"Element");

  e1 = [[Element alloc] initWithSummary:@"1"];
  e2 = [[Element alloc] initWithSummary:@"2"];

  PASS([e1 UID] != nil, "-UID works");
  PASS([e2 UID] != nil, "-UID works");
  PASS(![[e2 UID] isEqualToString:[e1 UID]], "Elements UIDs are different");

  [e1 release];
  [e2 release];

  Element *el = [Element new];
  PASS([el classification] == ICAL_CLASS_PUBLIC, "-classification works");
  PASS([el dateStamp] != nil, "-dateStamp works");
  PASS([el categories] != nil, "-categories works");
  PASS([[el categories] count] == 0, "categories array is empty");
  PASS(![el hasAlarms], "Element has no alarms");
  PASS([el alarms] != nil, "-alarms works");

  test_NSObject(@"Element", [NSArray arrayWithObject:el]);

  [el release];

  e3 = [[Element alloc] initWithSummary:@"NSCodingTest"];
  [e3 addCategory:@"Idea"];
  [e3 setText:[[NSAttributedString alloc] initWithString:@"Foo"]];
  al1 = [Alarm alarm];
  [al1 setSummary:@"Summary1"];
  [al1 setDesc:[[NSAttributedString alloc] initWithString:@"Desc1"]];
  [al1 setAbsoluteTrigger:[Date now]];
  al2 = [Alarm alarm];
  [al2 setSummary:@"Summary2"];
  [al2 setDesc:[[NSAttributedString alloc]initWithString:@"Desc2"]];
  [al2 setRelativeTrigger:3600.0];
  [e3 setAlarms:[NSArray arrayWithObjects:al1, al2, nil]];

  test_keyed_NSCoding([NSArray arrayWithObject:e3]);

  [e3 release];

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
