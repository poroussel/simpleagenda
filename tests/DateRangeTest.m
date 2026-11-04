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
  NSRange interSpan2 = [spanRange intersectionWithDay:otherDay];
  PASS(interSpan2.location == 0 && interSpan2.length == 3600,
       "-intersectionWithDay: starts at midnight on the second day");
  [spanRange release];

  /* Bounds, on [10h00, 12h00] */
  PASS([range contains:startDt], "-contains: YES for the start of the range");
  Date *end = [Date dateWithTimeInterval:7200 sinceDate:startDt];
  PASS([range contains:end], "-contains: YES for the end of the range");
  Date *afterEnd = [Date dateWithTimeInterval:7201 sinceDate:startDt];
  PASS(![range contains:afterEnd], "-contains: NO just after the end of the range");

  /* Adjacent ranges don't intersect */
  DateRange *adjacent = [[DateRange alloc] initWithStart:end duration:3600];
  PASS(![range intersectsWith:adjacent], "-intersectsWith: NO for a range starting at the end");
  PASS(![adjacent intersectsWith:range], "-intersectsWith: NO for a range ending at the start");
  [adjacent release];

  /* A range containing another one */
  DateRange *included = [[DateRange alloc] initWithStart:inside duration:60];
  PASS([range intersectsWith:included], "-intersectsWith: YES for an included range");
  PASS([included intersectsWith:range], "-intersectsWith: YES for an including range");
  [included release];

  /* A range longer than the day is clipped on both sides */
  Date *dayBefore = [day copy];
  [dayBefore changeDayBy:-1];
  DateRange *longRange = [[DateRange alloc] initWithStart:dayBefore duration:3 * 86400];
  NSRange interLong = [longRange intersectionWithDay:day];
  PASS(interLong.location == 0 && interLong.length == 86400,
       "-intersectionWithDay: of a longer range is the whole day");
  [longRange release];
  [dayBefore release];

  /* A range stopping at midnight doesn't intersect the next day */
  DateRange *wholeDay = [[DateRange alloc] initWithDay:day];
  PASS([wholeDay intersectsWithDay:day], "-intersectsWithDay: YES for its own day");
  PASS(![wholeDay intersectsWithDay:otherDay], "-intersectsWithDay: NO for the next day");
  PASS([wholeDay intersectionWithDay:otherDay].length == 0,
       "-intersectionWithDay: is empty for the next day");
  [wholeDay release];

  /* Datetimes are refused where days are expected */
  PASS_EXCEPTION(AUTORELEASE([[DateRange alloc] initWithDay:startDt]),
		 NSInternalInconsistencyException,
		 "-initWithDay: raises an exception on a datetime");
  PASS_EXCEPTION([range intersectsWithDay:startDt], NSInternalInconsistencyException,
		 "-intersectsWithDay: raises an exception on a datetime");
  PASS_EXCEPTION([range intersectionWithDay:startDt], NSInternalInconsistencyException,
		 "-intersectionWithDay: raises an exception on a datetime");

  PASS([[range description] rangeOfString:@"7200 seconds"].length > 0,
       "-description contains the length");

  [range release];
  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
