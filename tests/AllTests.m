#import "AllTests.h"
#import "DateTest.h"
#import "RecurrenceRuleTest.h"
#import "MemoryStoreTest.h"
#import "ElementTest.h"

@implementation AllTests
+ (AllTests *)suite
{
  return [[[self alloc] initWithName:@"All Example Tests"] autorelease];
}

- (id)initWithName:(NSString *)aName
{
  self = [super initWithName:aName];
  if (self) {
    [self addTest:[TestSuite suiteWithClass:[DateTest class]]];
    [self addTest:[TestSuite suiteWithClass:[ElementTest class]]];
    [self addTest:[TestSuite suiteWithClass:[RecurrenceRuleTest class]]];
    [self addTest:[TestSuite suiteWithClass:[MemoryStoreTest class]]];
  }
  return self;
}
@end
