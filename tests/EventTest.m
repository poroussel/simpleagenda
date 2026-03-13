/* -*- objc -*- */

#import "ObjectTesting.h"
#import "Event.h"
#import "Date.h"
#import "RecurrenceRule.h"

@implementation Event(Testing)
- (BOOL)isEqualForTestcase:(id)other
{
  if (other == nil || [other isKindOfClass:[Event class]] == NO)
    return NO;
  if ([[self summary] isEqualToString:[other summary]] == NO)
    return NO;
  if ([self duration] != [other duration])
    return NO;
  if ([self allDay] != [other allDay])
    return NO;
  if ([self sticky] != [other sticky])
    return NO;
  if (([self location] == nil) != ([other location] == nil))
    return NO;
  if ([self location] && ![[self location] isEqualToString:[other location]])
    return NO;
  /* compare:withTime:YES uses icaltime_compare which converts to UTC.
   * After an NSCoding round-trip, Date loses its timezone (icaltime_from_string
   * gives a floating time) so UTC conversion differs from the zoned original.
   * Compare date fields and time-of-day independently to avoid this. */
  if ([[self startDate] compare:[other startDate] withTime:NO] != NSOrderedSame)
    return NO;
  if ([[self startDate] minuteOfDay] != [[other startDate] minuteOfDay])
    return NO;
  return YES;
}
@end

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  test_alloc(@"Event");

  /* Build a datetime: 2024-06-15 14:30.
   * Use setIsDate:YES first to zero hour/minute/second (as shown by DateTest),
   * then setIsDate:NO to get a datetime at midnight before advancing. */
  Date *start = [Date now];
  [start setIsDate:YES];
  [start setYear:2024];
  [start setMonth:6];
  [start setDay:15];
  [start setIsDate:NO];       /* datetime at midnight, time zeroed */
  [start changeMinuteBy:870]; /* advance to 14h30 */

  Event *ev = [[Event alloc] initWithStartDate:start duration:60 title:@"Meeting"];

  PASS(ev != nil, "-initWithStartDate:duration:title: works");
  PASS([[ev summary] isEqualToString:@"Meeting"], "-summary returns title");
  PASS([ev duration] == 60, "-duration works");
  PASS([ev startDate] != nil, "-startDate works");
  PASS(![ev allDay], "-allDay is NO by default");
  PASS(![ev sticky], "-sticky is NO by default");
  PASS([ev location] == nil, "-location is nil by default");
  PASS([ev rrule] == nil, "-rrule is nil by default");

  /* location */
  [ev setLocation:@"Conference Room"];
  PASS([[ev location] isEqualToString:@"Conference Room"],
       "-setLocation: / location works");

  /* sticky */
  [ev setSticky:YES];
  PASS([ev sticky], "-setSticky:YES works");
  [ev setSticky:NO];
  PASS(![ev sticky], "-setSticky:NO works");

  /* details */
  PASS([[ev details] isEqualToString:@"14h30"], "-details returns correct time");

  test_NSObject(@"Event", [NSArray arrayWithObject:ev]);

  /* isScheduledForDay: */
  Date *day = [Date today];
  [day setYear:2024];
  [day setMonth:6];
  [day setDay:15];
  PASS([ev isScheduledForDay:day], "-isScheduledForDay: YES for same day");

  Date *otherDay = [Date today];
  [otherDay setYear:2024];
  [otherDay setMonth:6];
  [otherDay setDay:16];
  PASS(![ev isScheduledForDay:otherDay],
       "-isScheduledForDay: NO for different day");

  /* intersectionWithDay: */
  NSRange inter = [ev intersectionWithDay:day];
  PASS(inter.length > 0,
       "-intersectionWithDay: non-empty range for same day");
  PASS(inter.location == (NSUInteger)([[ev startDate] minuteOfDay] * 60),
       "-intersectionWithDay: offset matches event start time");
  PASS(inter.length == 3600,
       "-intersectionWithDay: length is 60 minutes in seconds");

  NSRange noInter = [ev intersectionWithDay:otherDay];
  PASS(noInter.length == 0,
       "-intersectionWithDay: empty range for different day");

  /* contains: */
  PASS([ev contains:@"Meeting"], "-contains: finds text in summary");
  PASS([ev contains:@"meeting"], "-contains: is case insensitive");
  PASS([ev contains:@"Conference"], "-contains: finds text in location");
  PASS(![ev contains:@"Birthday"], "-contains: NO for absent text");

  /* allDay */
  Event *allDayEv = [[Event alloc] initWithStartDate:day duration:0
                                               title:@"Holiday"];
  [allDayEv setAllDay:YES];
  PASS([allDayEv allDay], "-allDay returns YES after setAllDay:YES");
  PASS([allDayEv duration] == 1440, "-duration returns 1440 for allDay event");
  PASS([[allDayEv details] isEqualToString:@"all day"],
       "-details returns 'all day' for allDay event");
  PASS([allDayEv isScheduledForDay:day],
       "-isScheduledForDay: YES for allDay event on its day");

  /* NSCoding */
  test_keyed_NSCoding([NSArray arrayWithObject:ev]);

  /* Recurrence: weekly event should also appear 7 days later */
  RecurrenceRule *rule = [[RecurrenceRule alloc]
                          initWithFrequency:recurrenceFrequenceWeekly count:4];
  [ev setRRule:rule];
  PASS([ev rrule] != nil, "-setRRule: / rrule works");
  Date *weekLater = [day copy];
  [weekLater changeDayBy:7];
  PASS([ev isScheduledForDay:weekLater],
       "-isScheduledForDay: YES on weekly recurrence 7 days later");
  [rule release];

  /* dateRangeEnumerator: should yield DateRanges for each occurrence */
  RecurrenceRule *rule2 = [[RecurrenceRule alloc]
                           initWithFrequency:recurrenceFrequenceWeekly count:3];
  [ev setRRule:rule2];
  NSEnumerator *rangeEnum = [ev dateRangeEnumerator];
  int rangeCount = 0;
  id rangeObj;
  while ((rangeObj = [rangeEnum nextObject]))
    rangeCount++;
  PASS(rangeCount == 3, "-dateRangeEnumerator: yields correct number of ranges");
  [rule2 release];

  [ev release];
  [allDayEv release];
  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
