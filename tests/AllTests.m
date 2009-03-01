#import "AllTests.h"
#import "DateTest.h"
#import "RecurrenceRuleTest.h"

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
    [self addTest:[TestSuite suiteWithClass:[RecurrenceRuleTest class]]];
  }
  return self;
}
@end
