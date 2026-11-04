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

  /* UID */
  el = AUTORELEASE([[Element alloc] initWithSummary:@"UID"]);
  NSString *uid = [el UID];
  PASS([uid hasPrefix:@"SimpleAgenda-"], "generated UIDs have a prefix");
  PASS_EQUAL([el UID], uid, "-UID always returns the same value");
  [el generateUID];
  PASS(![[el UID] isEqualToString:uid], "-generateUID changes the UID");
  [el setUID:@"myUID"];
  PASS_EQUAL([el UID], @"myUID", "-setUID: works");

  /*
   * The UID is generated when first asked for : encoding an element must
   * generate it, or the decoded element would get a different one.
   */
  {
    Element *fresh = AUTORELEASE([[Element alloc] initWithSummary:@"Encoded"]);
    Element *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
					    [NSKeyedArchiver archivedDataWithRootObject:fresh]];

    PASS(decoded != nil && [decoded UID] != nil, "a decoded element has a UID");
    PASS_EQUAL([decoded UID], [fresh UID],
	       "an element encoded before its UID is asked for keeps it when decoded");
  }

  /* Simple accessors */
  [el setSummary:@"Summary"];
  PASS_EQUAL([el summary], @"Summary", "-setSummary: works");
  PASS([el text] == nil, "-text is nil by default");
  [el setText:AUTORELEASE([[NSAttributedString alloc] initWithString:@"Text"])];
  PASS_EQUAL([[el text] string], @"Text", "-setText: works");
  PASS([el store] == nil, "-store is nil by default");
  PASS([el nextActivationDate] == nil, "an Element has no activation date");

  [el setClassification:ICAL_CLASS_PRIVATE];
  PASS([el classification] == ICAL_CLASS_PRIVATE, "-setClassification: works");
  [el setClassification:(icalproperty_class)0];
  PASS([el classification] == ICAL_CLASS_PUBLIC,
       "-setClassification: uses ICAL_CLASS_PUBLIC instead of a wrong value");

  /* The date stamp is copied */
  Date *stamp = [NSKeyedUnarchiver unarchiveObjectWithData:
				     [NSKeyedArchiver archivedDataWithRootObject:[Date now]]];
  [el setDateStamp:stamp];
  PASS([el dateStamp] != stamp && [[el dateStamp] isEqual:stamp], "-setDateStamp: copies the date");

  /* Categories */
  PASS([[Element availableCategories] containsObject:@"Meeting"],
       "+availableCategories returns the categories");
  PASS(![el inCategory:@"Idea"], "-inCategory: NO for an unset category");
  [el addCategory:@"Idea"];
  PASS([el inCategory:@"Idea"], "-addCategory: works");
  [el addCategory:@"Idea"];
  PASS([[el categories] count] == 1, "-addCategory: doesn't add a category twice");
  [el addCategory:@"Travel"];
  PASS([[el categories] count] == 2, "an element can have multiple categories");
  [el removeCategory:@"Unknown"];
  PASS([[el categories] count] == 2, "-removeCategory: ignores an unset category");
  [el removeCategory:@"Idea"];
  PASS(![el inCategory:@"Idea"] && [el inCategory:@"Travel"], "-removeCategory: works");
  [el setCategories:[NSArray arrayWithObjects:@"a", @"b", nil]];
  PASS([el inCategory:@"a"] && [el inCategory:@"b"] && ![el inCategory:@"Travel"],
       "-setCategories: replaces the categories");

  /* Alarms */
  el = AUTORELEASE([[Element alloc] initWithSummary:@"Alarms"]);
  al1 = [Alarm alarm];
  [al1 setRelativeTrigger:60];
  [el addAlarm:al1];
  PASS([el hasAlarms] && [[el alarms] count] == 1, "-addAlarm: works");
  PASS([al1 element] == el, "-addAlarm: links the alarm to the element");

  al2 = [Alarm alarm];
  [al2 setRelativeTrigger:120];
  [el setAlarms:[NSArray arrayWithObject:al2]];
  PASS([[el alarms] count] == 1 && [[el alarms] lastObject] == al2,
       "-setAlarms: replaces the alarms");
  PASS([al2 element] == el, "-setAlarms: links the alarms to the element");

  PASS_RUNS([el addAlarm:al1], "-addAlarm: works after -setAlarms:");
  PASS([[el alarms] count] == 2, "-addAlarm: adds an alarm after -setAlarms:");
  /* -removeAlarm: is an empty FIXME */
  [el removeAlarm:al2];
  PASS(![[el alarms] containsObject:al2], "-removeAlarm: removes the alarm");

  [el setAlarms:nil];
  PASS(![el hasAlarms], "-setAlarms:nil removes all the alarms");

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
