/* -*- objc -*- */

#import "ObjectTesting.h"
#import "Date.h"

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  test_alloc(@"Date");

  Date *now = [Date now];
  Date *today = [Date today];
  Date *copy = [now copy];

  PASS(![now isDate], "+now works");
  PASS([today isDate], "+today works");

  [now setIsDate:YES];
  PASS([now isDate], "now is a date");
  PASS([now hourOfDay] == 0, "a date hourOfDay is 0");
  PASS([now minuteOfHour] == 0, "a date minuteOfHour is 0");
  PASS([now secondOfMinute] == 0, "a date secondOfMinute is 0");

  PASS([now compare:copy withTime:NO] == 0,
       "comparing with date only we have equality");
  PASS([now compare:copy withTime:YES] == -1,
       "no equality if comparing with time");
  [copy release];

  test_NSObject(@"Date", [NSArray arrayWithObject:now]);

  Date *distantDate = [Date dateWithTimeInterval:60 sinceDate:today];
  PASS([today compare:distantDate withTime:YES] == -1,
       "today must be inferior as distantDay is 1 hour later. bug if distantDate is a date as today, not a datetime");

  NSCalendarDate *cdate = [NSCalendarDate calendarDate];
  Date *date = [Date dateWithCalendarDate:cdate withTime:YES];
  PASS([cdate timeIntervalSinceDate:[date calendarDate]]<1,
       "going from a calendarDate to a date and back, the difference should less than 1 second, because of precision");

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
    PASS([tmp isDate],
	 "Every object enumerated is a single Date, not a Datetime.");
    if (last)
      PASS([tmp timeIntervalSinceDate:last]==86400,
	   "Each date returned is 86400 later than the preceding one.");
    ASSIGNCOPY(last, tmp);
  }
  PASS([last year] == 2009, "Year is the same.");
  PASS([last monthOfYear] == 1, "Month is the same.");
  PASS([last dayOfMonth] == 21, "1 + 20 = 21.");
  RELEASE(last);

/*
 * I'm not sure these tests are meaningful but they should
 * prevent some bugs...
 */
  Date *d1, *d2, *d3;
  struct icaltimetype iid;
  
  d1 = [Date now];

  iid = [d1 localICalTime];
  d2 = [[Date alloc] initWithICalTime:iid];
  PASS(([d1 compare:d2 withTime:YES] == NSOrderedSame), "");
  PASS([[d1 calendarDate] compare:[d2 calendarDate]] == NSOrderedSame, "");
  PASS([[d1 calendarDate] isEqualToDate:[d2 calendarDate]], "");
  [d2 release];

  iid = [d1 UTCICalTime];
  d3 = [[Date alloc] initWithICalTime:iid];
  PASS([d1 compare:d3 withTime:YES] == NSOrderedSame, "");
  PASS([[d1 calendarDate] compare:[d3 calendarDate]] == NSOrderedSame, "");
  PASS([[d1 calendarDate] isEqualToDate:[d3 calendarDate]], "");
  [d3 release];

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
