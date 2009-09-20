#import "ElementTest.h"
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

  [self assertTrue:([e1 UID] != nil) message:@"First element has an UID."];
  [self assertTrue:([e2 UID] != nil) message:@"Second element has an UID."];
  [self assertFalse:[[e2 UID] isEqualToString:[e1 UID]] message:@"But their UIDs are differents."];

  [e1 release];
  [e2 release];
}
@end
