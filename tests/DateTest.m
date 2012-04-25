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

  [now setIsDate:YES];
  [self assertTrue:[now isDate] message:@"now is a date"];
  [self assertInt:[now hourOfDay] equals:0 message:@"a date hourOfDay is 0"];
  [self assertInt:[now minuteOfHour] equals:0 message:@"a date minuteOfHour is 0"];
  [self assertInt:[now secondOfMinute] equals:0 message:@"a date secondOfMinute is 0"];

  [self assertInt:[now compare:copy withTime:NO] equals:0 message:@"comparing with date only we have equality"];
  [self assertInt:[now compare:copy withTime:YES] equals:-1];
  [copy release];

  Date *distantDate = [Date dateWithTimeInterval:60 sinceDate:today];
  [self assertInt:[today compare:distantDate withTime:YES] equals:-1 message:@"today must be inferior as distantDay is 1 hour later. bug if distantDate is a date as today, not a datetime"];
}

- (void)testDateManipulations
{
  NSCalendarDate *cdate = [NSCalendarDate calendarDate];
  Date *date = [Date dateWithCalendarDate:cdate withTime:YES];
  [self assertTrue:[cdate timeIntervalSinceDate:[date calendarDate]]<1 message:@"going from a calendarDate to a date and back, the difference should less than 1 second, because of precision"];
}

- (void)testDateEnumerator
{
  Date *start = [Date now];
  Date *end, *tmp, *last = nil;
  NSEnumerator *enumerator;

  [start setYear:2009];
  [start setMonth:1];
  [start setDay:1];
  end = [start copy];
  [end changeDayBy:20];
  enumerator = [start enumeratorTo:end];
  while ((tmp = [enumerator nextObject])) {
    [self assertTrue:[tmp isDate] message:@"Every object enumerated is a single Date, not a Datetime."];
    if (last)
      [self assertTrue:([tmp timeIntervalSinceDate:last]==86400) message:@"Each date returned is 86400 later than the preceding one."];
    ASSIGNCOPY(last, tmp);
  }
  [self assertInt:[last year] equals:2009 message:@"Year is the same."];
  [self assertInt:[last monthOfYear] equals:1 message:@"Month is the same."];
  [self assertInt:[last dayOfMonth] equals:21 message:@"1 + 20 = 21."];
  RELEASE(last);
}

/*
 * I'm not sure these tests are meaningful but they should
 * prevent some bugs...
 */
- (void)testTimeZone
{
  Date *d1, *d2, *d3;
  struct icaltimetype id;
  
  d1 = [Date now];

  id = [d1 localICalTime];
  d2 = [[Date alloc] initWithICalTime:id];
  [self assertTrue:[d1 compare:d2 withTime:YES] == NSOrderedSame];
  [self assertTrue:[[d1 calendarDate] compare:[d2 calendarDate]] == NSOrderedSame];
  [self assertTrue:[[d1 calendarDate] isEqualToDate:[d2 calendarDate]]];
  [d2 release];

  id = [d1 UTCICalTime];
  d3 = [[Date alloc] initWithICalTime:id];
  [self assertTrue:[d1 compare:d3 withTime:YES] == NSOrderedSame];
  [self assertTrue:[[d1 calendarDate] compare:[d3 calendarDate]] == NSOrderedSame];
  [self assertTrue:[[d1 calendarDate] isEqualToDate:[d3 calendarDate]]];
  [d3 release];
}
@end
