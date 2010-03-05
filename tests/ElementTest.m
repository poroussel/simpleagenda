#import "ElementTest.h"
#import "../MemoryStore.h"
#import "../Element.h"
#import "../Date.h"

@implementation ElementTest
- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testUID
{
  Element *e1, *e2;

  e1 = [[Element alloc] initWithSummary:@"1"];
  e2 = [[Element alloc] initWithSummary:@"2"];

  [self assertTrue:([e1 UID] != nil)];
  [self assertTrue:([e1 UID] != nil)];
  [self assertFalse:[[e2 UID] isEqualToString:[e1 UID]] message:@"Elements UIDs are differents."];

  [e1 release];
  [e2 release];
}

- (void)testDefaults
{
  Element *el = [Element new];

  [self assertTrue:([el classification] == ICAL_CLASS_PUBLIC)];
  [self assertNotNil:[el dateStamp]];
  [self assertNotNil:[el categories]];
  [self assertInt:[[el categories] count] equals:0];
  [self assertFalse:[el hasAlarms]];
  [self assertNotNil:[el alarms]];
  [el release];
}
@end
