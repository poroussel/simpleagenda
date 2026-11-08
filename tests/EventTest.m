/* -*- objc -*- */

#import "ObjectTesting.h"
#import "Event.h"
#import "Date.h"
#import "RecurrenceRule.h"
#import "Alarm.h"

/* Builds a date or a datetime in the local timezone from an iCalendar string */
static Date *dt(const char *string)
{
  return AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string(string)]);
}

static BOOL sameRange(NSRange range, NSUInteger location, NSUInteger length)
{
  if (length == 0)
    return range.length == 0;
  return range.location == location && range.length == length;
}

static Event *eventFromString(const char *string)
{
  icalcomponent *ic = icalparser_parse_string(string);
  Event *event = AUTORELEASE([[Event alloc] initWithICalComponent:ic]);

  icalcomponent_free(ic);
  return event;
}

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
  if ([self startDate] == nil || [other startDate] == nil)
    return [self startDate] == [other startDate];
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
  PASS([[ev location] isEqualToString:@"Conference Room"], "-setLocation: / location works");

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
  PASS(![ev isScheduledForDay:otherDay], "-isScheduledForDay: NO for different day");

  /* intersectionWithDay: */
  NSRange inter = [ev intersectionWithDay:day];
  PASS(inter.length > 0, "-intersectionWithDay: non-empty range for same day");
  PASS(inter.location == (NSUInteger)([[ev startDate] minuteOfDay] * 60), "-intersectionWithDay: offset matches event start time");
  PASS(inter.length == 3600, "-intersectionWithDay: length is 60 minutes in seconds");

  NSRange noInter = [ev intersectionWithDay:otherDay];
  PASS(noInter.length == 0, "-intersectionWithDay: empty range for different day");

  /* contains: */
  PASS([ev contains:@"Meeting"], "-contains: finds text in summary");
  PASS([ev contains:@"meeting"], "-contains: is case insensitive");
  PASS([ev contains:@"Conference"], "-contains: finds text in location");
  PASS(![ev contains:@"Birthday"], "-contains: NO for absent text");

  /* allDay */
  Event *allDayEv = [[Event alloc] initWithStartDate:day duration:0 title:@"Holiday"];
  [allDayEv setAllDay:YES];
  PASS([allDayEv allDay], "-allDay returns YES after setAllDay:YES");
  PASS([allDayEv duration] == 1440, "-duration returns 1440 for allDay event");
  PASS([[allDayEv details] isEqualToString:@"all day"], "-details returns 'all day' for allDay event");
  PASS([allDayEv isScheduledForDay:day], "-isScheduledForDay: YES for allDay event on its day");

  /* NSCoding — manual round-trip instead of test_keyed_NSCoding, which wraps
   * everything in NS_DURING and silently fails the whole set if any step raises
   * (e.g. a nil startDate dereference inside isEqualForTestcase:). */
  {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:ev];
    PASS(data != nil && [data length] > 0, "Event can be archived");
    Event *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    PASS(decoded != nil, "Event can be unarchived");
    PASS([[decoded summary] isEqualToString:[ev summary]], "NSCoding preserves summary");
    PASS([decoded duration] == [ev duration], "NSCoding preserves duration");
    PASS([decoded allDay] == [ev allDay], "NSCoding preserves allDay");
    PASS([decoded sticky] == [ev sticky], "NSCoding preserves sticky");
    PASS([[decoded location] isEqualToString:[ev location]], "NSCoding preserves location");
    PASS([[decoded startDate] compare:[ev startDate] withTime:NO] == NSOrderedSame && [[decoded startDate] minuteOfDay] == [[ev startDate] minuteOfDay],"NSCoding preserves startDate");
  }

  /* Recurrence: weekly event should also appear 7 days later */
  RecurrenceRule *rule = [[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceWeekly count:4];
  [ev setRRule:rule];
  PASS([ev rrule] != nil, "-setRRule: / rrule works");
  Date *weekLater = [day copy];
  [weekLater changeDayBy:7];
  PASS([ev isScheduledForDay:weekLater], "-isScheduledForDay: YES on weekly recurrence 7 days later");
  [rule release];

  /* occurrenceEnumerator: should yield a date for each occurrence */
  RecurrenceRule *rule2 = [[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceWeekly count:3];
  [ev setRRule:rule2];
  NSEnumerator *occurrenceEnum = [ev occurrenceEnumerator];
  int occurrenceCount = 0;
  id occurrence;
  while ((occurrence = [occurrenceEnum nextObject]))
    occurrenceCount++;
  PASS(occurrenceCount == 3, "-occurrenceEnumerator: yields correct number of occurrences");
  [rule2 release];

  [ev release];
  [allDayEv release];

  /* Small accessors */
  Date *fixed = dt("20240615T143000");
  Event *e = AUTORELEASE([[Event alloc] initWithStartDate:fixed duration:90 title:@"Title"]);
  PASS([e startDate] != fixed, "-setStartDate: copies the date");
  [fixed changeDayBy:1];
  PASS([[e startDate] dayOfMonth] == 15, "modifying the given date doesn't change the event");
  PASS([[e nextActivationDate] dayOfMonth] == 15, "-nextActivationDate is the start date");
  [e setDuration:30];
  PASS([e duration] == 30, "-setDuration: works");
  PASS([[e description] rangeOfString:@"Title"].length > 0, "-description contains the summary");
  [e setText:AUTORELEASE([[NSAttributedString alloc] initWithString:@"Some Text"])];
  PASS([e contains:@"some text"], "-contains: finds text in the description");
  [e setSummary:nil];
  PASS(![e contains:@"Title"], "-contains: works without a summary");
  [e setSummary:@"Title"];

  /* Copy. The UID is generated when first asked for, get it before copying */
  NSString *originalUID = [e UID];
  Event *copied = AUTORELEASE([e copy]);
  PASS(copied != e && [[copied summary] isEqual:@"Title"] && [copied duration] == 30, "-copy duplicates the event");
  PASS(![[copied UID] isEqualToString:originalUID], "-copy gives a new UID");
  PASS_EQUAL([e UID], originalUID, "-copy doesn't change the UID of the original");

  /* Recurrences : weekly on saturdays, 3 times */
  Event *rec = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240615T143000") duration:60 title:@"Recurrent"]);
  [rec setRRule:AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceWeekly count:3])];
  PASS([rec isScheduledForDay:dt("20240615")], "first occurrence");
  PASS([rec isScheduledForDay:dt("20240629")], "last occurrence");
  PASS([rec isScheduledForDay:dt("20240622")], "second occurrence");
  PASS(![rec isScheduledForDay:dt("20240616")], "no occurrence the day after");
  PASS(![rec isScheduledForDay:dt("20240706")], "no occurrence after the last one");
  PASS(![rec isScheduledForDay:dt("20240608")], "no occurrence before the first one");
  PASS([rec intersectionWithDay:dt("20240622")].location == 870 * 60 && [rec intersectionWithDay:dt("20240622")].length == 3600, "-intersectionWithDay: works on an occurrence");
  PASS([rec nextActivationDate] == nil, "a recurrent event has no -nextActivationDate");

  /* NSCoding keeps the recurrence rule */
  {
    /* The UID is generated when first asked for, get it before archiving */
    NSString *uid = [rec UID];
    Event *decoded = [NSKeyedUnarchiver unarchiveObjectWithData: [NSKeyedArchiver archivedDataWithRootObject:rec]];
    PASS([decoded rrule] != nil && [[decoded rrule] frequency] == recurrenceFrequenceWeekly && [[decoded rrule] count] == 3, "NSCoding preserves the recurrence rule");
    PASS([decoded isScheduledForDay:dt("20240629")], "a decoded recurrent event still works");
    PASS_EQUAL([decoded UID], uid, "NSCoding preserves the UID");
  }

  /* All day range */
  Event *allDay = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240615") duration:0 title:@"All day"]);
  [allDay setAllDay:YES];
  [allDay setRRule:AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily count:2])];
  PASS([allDay duration] == 1440, "an all day event lasts a whole day");
  PASS([[[allDay occurrenceEnumerator] nextObject] isDate], "-occurrenceEnumerator of an all day event gives dates");
  PASS([allDay intersectionWithDay:dt("20240616")].length == 86400, "an all day recurrence covers the whole day");

  /* Intersections with a day */
  {
    Event *e;
    RecurrenceRule *r;

    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240615T230000") duration:120 title:@"Span"]);
    PASS(sameRange([e intersectionWithDay:dt("20240615")], 82800, 3600),
	 "-intersectionWithDay: of an event spanning midnight stops at midnight");
    PASS(sameRange([e intersectionWithDay:dt("20240616")], 0, 3600),
	 "-intersectionWithDay: of an event spanning midnight starts at midnight the next day");
    PASS(sameRange([e intersectionWithDay:dt("20240617")], 0, 0),
	 "-intersectionWithDay: of an event spanning midnight is empty two days later");

    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240614T120000") duration:3 * 1440 title:@"Long"]);
    PASS(sameRange([e intersectionWithDay:dt("20240615")], 0, 86400),
	 "-intersectionWithDay: of a longer event is the whole day");

    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240615T220000") duration:120 title:@"Midnight"]);
    PASS(sameRange([e intersectionWithDay:dt("20240615")], 79200, 7200),
	 "-intersectionWithDay: of an event ending at midnight");
    PASS(sameRange([e intersectionWithDay:dt("20240616")], 0, 0),
	 "an event ending at midnight doesn't intersect the next day");

    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240615T100000") duration:-60 title:@"Negative"]);
    PASS(sameRange([e intersectionWithDay:dt("20240615")], 0, 0),
	 "an event with a negative duration doesn't intersect its day");
    PASS_EXCEPTION([e intersectionWithDay:dt("20240615T100000")], NSInternalInconsistencyException,
		   "-intersectionWithDay: raises an exception on a datetime");

    /* Daily at 23h00 for 2 hours, 3 times : the 15th, 16th and 17th */
    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240615T230000") duration:120 title:@"Nightly"]);
    [e setRRule:AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily count:3])];
    PASS(sameRange([e intersectionWithDay:dt("20240615")], 82800, 3600),
	 "-intersectionWithDay: of the first occurrence");
    PASS(sameRange([e intersectionWithDay:dt("20240616")], 0, 3600),
	 "-intersectionWithDay: gives the first occurrence touching the day");
    PASS(sameRange([e intersectionWithDay:dt("20240618")], 0, 3600),
	 "-intersectionWithDay: gives the end of the last occurrence the next day");
    PASS(sameRange([e intersectionWithDay:dt("20240619")], 0, 0),
	 "-intersectionWithDay: is empty after the last occurrence");
    PASS(sameRange([e intersectionWithDay:dt("20240614")], 0, 0),
	 "-intersectionWithDay: is empty before the first occurrence");
    PASS_EXCEPTION([e intersectionWithDay:dt("20240615T100000")], NSInternalInconsistencyException,
		   "-intersectionWithDay: of a recurrent event raises an exception on a datetime");

    [e setDuration:-60];
    PASS(sameRange([e intersectionWithDay:dt("20240616")], 0, 0),
	 "a recurrent event with a negative duration doesn't intersect its days");

    /* A rule ending before the start */
    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240615T100000") duration:60 title:@"Ended"]);
    r = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily until:dt("20240601")]);
    [e setRRule:r];
    PASS(sameRange([e intersectionWithDay:dt("20240615")], 0, 0),
	 "an event whose rule ends before its start has no occurrence");
    PASS(sameRange([e intersectionWithDay:dt("20240616")], 0, 0),
	 "an event whose rule ends before its start isn't scheduled the next day");

    /*
     * Intersections use the local time without the timezone : days have 24
     * hours, even when DST starts (Europe/Paris on 2024-03-31)
     */
    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240401T003000") duration:30 title:@"DST"]);
    PASS(sameRange([e intersectionWithDay:dt("20240331")], 0, 0),
	 "an event doesn't intersect the previous day when DST starts");
    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240331T013000") duration:120 title:@"DST"]);
    PASS(sameRange([e intersectionWithDay:dt("20240331")], 5400, 7200),
	 "-intersectionWithDay: uses the local time when DST starts");
  }

  /* iCalendar : round trip of all the properties */
  {
    Event *src = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240615T143000")
						     duration:90 title:@"Round trip \303\251"]);
    Alarm *alarm = [Alarm alarm];
    [alarm setRelativeTrigger:-600];
    [src addAlarm:alarm];
    [src setLocation:@"Room"];
    [src setSticky:YES];
    [src setClassification:ICAL_CLASS_PRIVATE];
    [src addCategory:@"Idea"];
    [src addCategory:@"Travel"];
    [src setText:AUTORELEASE([[NSAttributedString alloc] initWithString:@"Text"])];
    [src setRRule:AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily count:5])];

    icalcomponent *ic = [src asICalComponent];
    PASS(ic != NULL && icalcomponent_isa(ic) == ICAL_VEVENT_COMPONENT, "-asICalComponent returns a VEVENT");
    Event *dst = AUTORELEASE([[Event alloc] initWithICalComponent:ic]);
    PASS(dst != nil, "-initWithICalComponent: works");
    PASS_EQUAL([dst UID], [src UID], "iCalendar preserves the UID");
    PASS_EQUAL([dst summary], [src summary], "iCalendar preserves the summary");
    PASS_EQUAL([dst location], @"Room", "iCalendar preserves the location");
    PASS_EQUAL([[dst text] string], @"Text", "iCalendar preserves the text");
    PASS([dst classification] == ICAL_CLASS_PRIVATE, "iCalendar preserves the classification");
    PASS([dst inCategory:@"Idea"] && [dst inCategory:@"Travel"], "iCalendar preserves the categories");
    PASS([dst sticky], "iCalendar preserves the sticky state");
    PASS(![dst allDay], "iCalendar preserves the all day state");
    PASS([dst duration] == 90, "iCalendar preserves the duration");
    PASS([[dst startDate] compare:[src startDate] withTime:YES] == NSOrderedSame && [[dst startDate] minuteOfDay] == 870, "iCalendar preserves the local start time");
    PASS([[dst rrule] frequency] == recurrenceFrequenceDaily && [[dst rrule] count] == 5, "iCalendar preserves the recurrence rule");
    PASS([[dst alarms] count] == 1 && [[[dst alarms] lastObject] relativeTrigger] == -600, "iCalendar preserves the alarms");
    PASS([[[dst alarms] lastObject] element] == dst, "iCalendar links the alarms to the event");

    /* Updating a component replaces the properties instead of adding new ones */
    [src setSummary:@"Updated"];
    [src setLocation:nil];
    [src setSticky:NO];
    [src setRRule:nil];
    [src setText:nil];
    [src setCategories:[NSArray array]];
    [src setAlarms:[NSArray array]];
    PASS([src updateICalComponent:ic], "-updateICalComponent: works");
    PASS(icalcomponent_count_properties(ic, ICAL_SUMMARY_PROPERTY) == 1, "only one SUMMARY");
    PASS(icalcomponent_count_properties(ic, ICAL_DTSTART_PROPERTY) == 1, "only one DTSTART");
    PASS(icalcomponent_count_properties(ic, ICAL_DTEND_PROPERTY) == 1, "only one DTEND");
    PASS(icalcomponent_count_properties(ic, ICAL_UID_PROPERTY) == 1, "only one UID");
    PASS(icalcomponent_count_properties(ic, ICAL_LOCATION_PROPERTY) == 0, "the location is removed");
    PASS(icalcomponent_count_properties(ic, ICAL_RRULE_PROPERTY) == 0, "the rule is removed");
    PASS(icalcomponent_count_properties(ic, ICAL_DESCRIPTION_PROPERTY) == 0, "the text is removed");
    PASS(icalcomponent_count_properties(ic, ICAL_CATEGORIES_PROPERTY) == 0, "the categories are removed");
    PASS(icalcomponent_count_properties(ic, ICAL_X_PROPERTY) == 0, "the sticky state is removed");
    PASS(icalcomponent_count_components(ic, ICAL_VALARM_COMPONENT) == 0, "the alarms are removed");
    dst = AUTORELEASE([[Event alloc] initWithICalComponent:ic]);
    PASS_EQUAL([dst summary], @"Updated", "-updateICalComponent: writes the new values");
    PASS(![dst sticky], "the event isn't sticky anymore");
    icalcomponent_free(ic);
  }

  /* iCalendar : all day events */
  {
    Event *src = AUTORELEASE([[Event alloc] initWithStartDate:dt("20240615") duration:0 title:@"All day"]);
    icalcomponent *ic;
    Event *dst;

    [src setAllDay:YES];
    ic = [src asICalComponent];
    dst = AUTORELEASE([[Event alloc] initWithICalComponent:ic]);
    PASS([dst allDay] && [dst duration] == 1440, "iCalendar preserves an all day event");
    PASS([[dst startDate] isDate] && [[dst startDate] compare:dt("20240615") withTime:NO] == NSOrderedSame, "an all day event stays on its day");
    PASS([[dt("20240616") description] isEqualToString:[AUTORELEASE([[Date alloc] initWithICalTime:icalcomponent_get_dtend(ic)]) description]], "DTEND of an all day event is the next day");
    [src updateICalComponent:ic];
    PASS(icalcomponent_count_properties(ic, ICAL_X_PROPERTY) == 1, "the all day property isn't added twice by an update");
    icalcomponent_free(ic);
  }

#define VEVENT(content) ("BEGIN:VEVENT\r\n" content "END:VEVENT\r\n")

  /* iCalendar : reading external components */
  {
    Event *dst;

    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART:20240615T100000\r\nDURATION:PT45M\r\n"));
    PASS(dst != nil && [dst duration] == 45 && ![dst allDay], "DURATION is read");

    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART:20240615T100000\r\nDTEND:20240615T120000\r\n"));
    PASS(dst != nil && [dst duration] == 120, "DTEND is converted to a duration");

    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART:20240615T100000\r\n"));
    PASS(dst != nil && [dst allDay], "an event without end nor duration is an all day one");

    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART;VALUE=DATE:20240615\r\n"));
    PASS(dst != nil && [dst allDay] && [[dst startDate] dayOfMonth] == 15, "an event starting on a date is an all day one");

    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART:20240615T100000\r\nDTEND:20240615T110000\r\nRRULE:FREQ=WEEKLY;BYDAY=MO,TU\r\n"));
    PASS([[dst rrule] frequency] == recurrenceFrequenceWeekly, "RRULE is read");
    PASS([dst isScheduledForDay:dt("20240617")] && [dst isScheduledForDay:dt("20240618")] && ![dst isScheduledForDay:dt("20240619")], "BYDAY is taken into account");

    dst = eventFromString(VEVENT("SUMMARY:S\r\nDTSTART:20240615T100000\r\n"));
    PASS(dst == nil, "an event without UID is refused");
    dst = eventFromString(VEVENT("UID:1\r\nDTSTART:20240615T100000\r\n"));
    PASS(dst == nil, "an event without SUMMARY is refused");
    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\n"));
    PASS(dst == nil, "an event without DTSTART is refused");

    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART:20240615T100000\r\nDURATION:PT1H\r\nX-SIMPLEAGENDA-STICKY:TRUE\r\n"));
    PASS([dst sticky], "X-SIMPLEAGENDA-STICKY:TRUE is read");
    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART:20240615T100000\r\nDURATION:PT1H\r\nX-SIMPLEAGENDA-STICKY:FALSE\r\n"));
    PASS(![dst sticky], "X-SIMPLEAGENDA-STICKY:FALSE is read");

    /* libical accepts out of range fields : the start date must be normalized */
    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART;VALUE=DATE:20262311\r\n"));
    PASS_EQUAL([[dst startDate] description], @"20271111",
	       "an all day event starting in month 23 starts in november of the next year");
    PASS([dst isScheduledForDay:dt("20271111")],
	 "an all day event starting in month 23 is scheduled on its normalized day");
    dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART:20260230T100000\r\nDURATION:PT1H\r\n"));
    PASS([[dst startDate] monthOfYear] == 3 && [[dst startDate] dayOfMonth] == 2,
	 "an event starting on february 30th starts on march 2nd");
    PASS([dst isScheduledForDay:dt("20260302")],
	 "an event starting on february 30th is scheduled on march 2nd");

    /* LocalStore saves events with NSKeyedArchiver : an event loaded from
     * it and exported again must keep its start instant */
    {
      icalcomponent *ic;
      struct icaltimetype start;

      dst = eventFromString(VEVENT("UID:1\r\nSUMMARY:S\r\nDTSTART:20240615T100000Z\r\nDURATION:PT1H\r\n"));
      dst = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:dst]];
      ic = [dst asICalComponent];
      start = icalcomponent_get_dtstart(ic);
      PASS(icaltime_compare(start, icaltime_from_string("20240615T100000Z")) == 0
	   && start.hour == 10,
	   "an archived event is exported with its original UTC start");
      icalcomponent_free(ic);
    }
  }

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
