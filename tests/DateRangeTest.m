/* -*- objc -*- */

#import "ObjectTesting.h"
#import "DateRange.h"
#import "Date.h"

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  test_alloc(@"DateRange");

  /* Fixed day: 2024-06-15 */
  Date *day = [Date today];
  [day setYear:2024];
  [day setMonth:6];
  [day setDay:15];

  /* initWithDay: */
  DateRange *dayRange = [[DateRange alloc] initWithDay:day];
  PASS(dayRange != nil, "-initWithDay: works");
  PASS([dayRange length] == 86400, "-initWithDay: length is 86400 seconds");
  PASS([[dayRange start] compare:day withTime:NO] == NSOrderedSame,
       "-initWithDay: start matches the day");
  [dayRange release];

  /* Datetime at 10h00 on 2024-06-15 */
  Date *startDt = [Date today];
  [startDt setYear:2024];
  [startDt setMonth:6];
  [startDt setDay:15];
  [startDt setIsDate:NO];
  [startDt changeMinuteBy:600]; /* 10h00 */

  /* initWithStart:duration: */
  DateRange *range = [[DateRange alloc] initWithStart:startDt duration:7200];
  PASS(range != nil, "-initWithStart:duration: works");
  PASS([range length] == 7200, "-length returns correct duration");
  PASS([[range start] compare:startDt withTime:YES] == NSOrderedSame,
       "-start returns correct start date");

  test_NSObject(@"DateRange", [NSArray arrayWithObject:range]);

  /* setStart: / setLength: */
  Date *newStart = [Date today];
  [newStart setYear:2024];
  [newStart setMonth:6];
  [newStart setDay:15];
  [newStart setIsDate:NO];
  [newStart changeMinuteBy:480]; /* 8h00 */
  [range setStart:newStart];
  PASS([[range start] compare:newStart withTime:YES] == NSOrderedSame,
       "-setStart: works");
  [range setLength:3600];
  PASS([range length] == 3600, "-setLength: works");

  /* Restore range to [10h00, 12h00) */
  [range setStart:startDt];
  [range setLength:7200];

  /* contains: — datetime at 11h00 inside [10h00, 12h00) */
  Date *inside = [Date today];
  [inside setYear:2024];
  [inside setMonth:6];
  [inside setDay:15];
  [inside setIsDate:NO];
  [inside changeMinuteBy:660]; /* 11h00 */
  PASS([range contains:inside], "-contains: YES for datetime inside range");

  /* before range */
  Date *before = [Date today];
  [before setYear:2024];
  [before setMonth:6];
  [before setDay:15];
  [before setIsDate:NO];
  [before changeMinuteBy:540]; /* 9h00 */
  PASS(![range contains:before], "-contains: NO for datetime before range");

  /* after range */
  Date *after = [Date today];
  [after setYear:2024];
  [after setMonth:6];
  [after setDay:15];
  [after setIsDate:NO];
  [after changeMinuteBy:780]; /* 13h00 */
  PASS(![range contains:after], "-contains: NO for datetime after range");

  /* intersectsWith: — overlapping range [11h00, 12h00) vs [10h00, 12h00) */
  DateRange *overlapping = [[DateRange alloc] initWithStart:inside duration:3600];
  PASS([range intersectsWith:overlapping],
       "-intersectsWith: YES for overlapping ranges");
  [overlapping release];

  /* intersectsWith: — non-overlapping range [15h00, 16h00) vs [10h00, 12h00) */
  Date *farStart = [Date today];
  [farStart setYear:2024];
  [farStart setMonth:6];
  [farStart setDay:15];
  [farStart setIsDate:NO];
  [farStart changeMinuteBy:900]; /* 15h00 */
  DateRange *noOverlap = [[DateRange alloc] initWithStart:farStart duration:3600];
  PASS(![range intersectsWith:noOverlap],
       "-intersectsWith: NO for non-overlapping ranges");
  [noOverlap release];

  /* intersectsWithDay: */
  PASS([range intersectsWithDay:day],
       "-intersectsWithDay: YES for event on same day");
  Date *otherDay = [Date today];
  [otherDay setYear:2024];
  [otherDay setMonth:6];
  [otherDay setDay:16];
  PASS(![range intersectsWithDay:otherDay],
       "-intersectsWithDay: NO for different day");

  /* intersectionWithDay: — event at [10h00, 12h00) on 2024-06-15 */
  NSRange inter = [range intersectionWithDay:day];
  PASS(inter.length > 0,
       "-intersectionWithDay: non-empty range for same day");
  PASS(inter.location == (NSUInteger)(10 * 3600),
       "-intersectionWithDay: offset is 10h from midnight");
  PASS(inter.length == 7200,
       "-intersectionWithDay: length matches duration");

  NSRange noInter = [range intersectionWithDay:otherDay];
  PASS(noInter.length == 0,
       "-intersectionWithDay: empty range for different day");

  /* Event spanning midnight: [23h00 on June 15, 01h00 on June 16] */
  Date *lateStart = [Date today];
  [lateStart setYear:2024];
  [lateStart setMonth:6];
  [lateStart setDay:15];
  [lateStart setIsDate:NO];
  [lateStart changeMinuteBy:1380]; /* 23h00 */
  DateRange *spanRange = [[DateRange alloc] initWithStart:lateStart
                                                 duration:7200]; /* +2h */
  PASS([spanRange intersectsWithDay:day],
       "-intersectsWithDay: YES for range starting on day 1");
  PASS([spanRange intersectsWithDay:otherDay],
       "-intersectsWithDay: YES for range ending on day 2");

  NSRange interSpan = [spanRange intersectionWithDay:day];
  PASS(interSpan.length == 3600,
       "-intersectionWithDay: clipped to 1h at end of first day");
  [spanRange release];

  [range release];
  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
