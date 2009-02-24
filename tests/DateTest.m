#import "DateTest.h"
#import "../Date.h"

@implementation DateTest

- (void)setUp
{
}

- (void)tearDown
{
}

- (void)testDateAndDateTime
{
  Date *now = [Date now];
  Date *today = [Date today];
  Date *copy = [now copy];

  [self assertFalse:[now isDate]];
  [self assertTrue:[today isDate]];

  [now setDate:YES];
  [self assertTrue:[now isDate] message:@"now is a date"];
  [self assertInt:[now hourOfDay] equals:0 message:@"a date hourOfDay is 0"];
  [self assertInt:[now minuteOfHour] equals:0 message:@"a date minuteOfHour is 0"];
  [self assertInt:[now secondOfMinute] equals:0 message:@"a date secondOfMinute is 0"];

  [self assertInt:[now compare:copy] equals:0 message:@"comparing with date only we have equality"];
  [self assertInt:[now compareTime:copy] equals:-1];
  [copy release];
}

- (void)testDateManipulations
{
}

@end
