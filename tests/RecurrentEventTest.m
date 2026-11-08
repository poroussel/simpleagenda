/* -*- objc -*- */

/*
 * Recurrent events : problems found by tests/fuzz/FuzzRecur.
 *
 * Problems in libical (3.0) are hopes (testHopeful), as SimpleAgenda
 * can only work around them. Problems in SimpleAgenda (findings 1 to 4 in
 * findings.md) are hopes too until they are fixed : remove the
 * testHopeful lines around a finding's tests when it is fixed.
 */

#import "ObjectTesting.h"
#import "Event.h"
#import "Date.h"
#import "RecurrenceRule.h"

#define VEVENT(content) ("BEGIN:VEVENT\r\nUID:1\r\nSUMMARY:S\r\n" content "END:VEVENT\r\n")

/* Builds a date or a datetime in the local timezone from an iCalendar string */
static Date *dt(const char *string)
{
  return AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string(string)]);
}

static Event *eventFromString(const char *string)
{
  icalcomponent *ic = icalparser_parse_string(string);
  Event *event = AUTORELEASE([[Event alloc] initWithICalComponent:ic]);

  icalcomponent_free(ic);
  return event;
}

static Event *archived(Event *event)
{
  return [NSKeyedUnarchiver unarchiveObjectWithData:
			      [NSKeyedArchiver archivedDataWithRootObject:event]];
}

/* The start of the first occurrences (at most max), separated by spaces */
static NSString *occurrences(Event *event, int max)
{
  NSMutableArray *dates = [NSMutableArray array];
  NSEnumerator *enumerator = [event occurrenceEnumerator];
  Date *date;

  while ([dates count] < max && (date = [enumerator nextObject]))
    [dates addObject:[date description]];
  return [dates componentsJoinedByString:@" "];
}

static BOOL isDST(const char *date)
{
  return [[NSTimeZone defaultTimeZone]
	   isDaylightSavingTimeForDate:[dt(date) calendarDate]];
}

int main()
{
  CREATE_AUTORELEASE_POOL(arp);
  Event *event;

  /*
   * Finding 1 : RSCALE (RFC 7529). struct icalrecurrencetype has a
   * char *rscale owned by the RRULE property value. A rule that pointed
   * into the component read freed memory when -updateICalComponent:
   * replaced the RRULE property (heap-use-after-free under
   * AddressSanitizer) : RecurrenceRule now owns a copy
   */
  {
    icalcomponent *ic;
    icalproperty *prop;
    struct icalrecurrencetype rule;
    struct icalrecurrencetype exported;

    ic = icalparser_parse_string(VEVENT("DTSTART:20240315T100000Z\r\nDURATION:PT1H\r\n"
					"RRULE:RSCALE=GREGORIAN;FREQ=YEARLY\r\n"));
    prop = icalcomponent_get_first_property(ic, ICAL_RRULE_PROPERTY);
    event = AUTORELEASE([[Event alloc] initWithICalComponent:ic]);
    rule = [[event rrule] iCalRRule];
    PASS(rule.rscale != NULL && !strcmp(rule.rscale, "GREGORIAN"),
	 "an event reads the RSCALE of its rule");
    PASS(rule.rscale != icalproperty_get_rrule(prop).rscale,
	 "the rule of an event doesn't share its RSCALE with the iCalendar component");

    PASS([event updateICalComponent:ic], "an event with an RSCALE can be saved");
    prop = icalcomponent_get_first_property(ic, ICAL_RRULE_PROPERTY);
    exported = prop ? icalproperty_get_rrule(prop) : rule;
    PASS(prop != NULL && exported.rscale != NULL && !strcmp(exported.rscale, "GREGORIAN"),
	 "an event saved in its own component keeps its RSCALE");
    icalcomponent_free(ic);
    rule = [[archived(event) rrule] iCalRRule];
    PASS(rule.rscale != NULL && !strcmp(rule.rscale, "GREGORIAN"),
	 "an archived rule keeps its RSCALE");
  }

  /*
   * Finding 2 : a rule that never matches, like the 53rd monday of a
   * month. libical looks for it for about a second, and the views call
   * -isScheduledForDay: for each day they show. Such rules are detected
   * without libical, and an event remembers it has no occurrence
   */
  {
    NSDate *start;
    NSTimeInterval elapsed;
    Date *day;
    int i;

    event = eventFromString(VEVENT("DTSTART:20240101T080000Z\r\nDURATION:PT1H\r\n"
				   "RRULE:FREQ=MONTHLY;BYDAY=MO;BYSETPOS=53\r\n"));
    start = [NSDate date];
    [event isScheduledForDay:dt("20240102")];
    elapsed = -[start timeIntervalSinceNow];
    PASS(elapsed < 0.1,
	 "-isScheduledForDay: is fast for a rule without any occurrence (%.2fs)", elapsed);

    event = eventFromString(VEVENT("DTSTART:20240101T080000\r\nDURATION:PT1H\r\n"
				   "RRULE:FREQ=HOURLY;BYMONTH=2;BYMONTHDAY=30\r\n"));
    start = [NSDate date];
    [event isScheduledForDay:dt("20240102")];
    elapsed = -[start timeIntervalSinceNow];
    PASS(elapsed < 0.1,
	 "-isScheduledForDay: is fast for an hourly rule on a day that doesn't exist (%.2fs)", elapsed);

    /* Not detected (0.15s to look for it) : the event remembers it */
    event = eventFromString(VEVENT("DTSTART:20240101T080000\r\nDURATION:PT1H\r\n"
				   "RRULE:FREQ=YEARLY;BYDAY=MO;BYSETPOS=54\r\n"));
    PASS(![event hasOccurrences], "an event whose rule never matches has no occurrence");
    day = dt("20240101");
    start = [NSDate date];
    for (i = 0; i < 42; i++) {
      [event isScheduledForDay:day];
      [day incrementDay];
    }
    elapsed = -[start timeIntervalSinceNow];
    PASS(elapsed < 0.1,
	 "42 days of an event without occurrence are fast (%.2fs)", elapsed);
  }

  /* -hasOccurrences follows the start and the rule */
  {
    Date *before;

    event = eventFromString(VEVENT("DTSTART:20240615T100000\r\nDURATION:PT1H\r\n"
				   "RRULE:FREQ=DAILY;UNTIL=20240601T000000\r\n"));
    PASS(![event hasOccurrences] && ![event isScheduledForDay:dt("20240615")],
	 "an event starting after its UNTIL has no occurrence");
    before = dt("20240530T100000");
    [[event startDate] changeDayBy:-16];
    PASS([event hasOccurrences] && [event isScheduledForDay:dt("20240531")],
	 "an event moved in place before its UNTIL has occurrences");
    [event setStartDate:dt("20240615T100000")];
    PASS(![event hasOccurrences], "-setStartDate: is taken into account");
    [event setStartDate:before];
    [event setRRule:AUTORELEASE([[RecurrenceRule alloc] initWithICalRRule:
				    icalrecurrencetype_from_string("FREQ=MONTHLY;BYDAY=MO;BYSETPOS=53")])];
    PASS(![event hasOccurrences], "-setRRule: is taken into account");
    [event setRRule:nil];
    PASS([event hasOccurrences], "an event that doesn't repeat has an occurrence");
  }

  /*
   * Finding 3 : RFC 5545 3.6.1, a VEVENT with a DATE-TIME DTSTART and no
   * DTEND or DURATION ends at its start. SimpleAgenda made it an all day
   * event and dropped its time when it was saved
   */
  {
    icalcomponent *ic;
    struct icaltimetype start;

    event = eventFromString(VEVENT("DTSTART:20240315T100000Z\r\nRRULE:FREQ=WEEKLY;COUNT=3\r\n"));
    PASS(event != nil && ![event allDay],
	 "an event with a start time and no end isn't an all day event");
    PASS(event != nil && [event duration] == 0,
	 "an event with a start time and no end has no duration");
    PASS(event != nil && ![[event startDate] isDate],
	 "an event with a start time and no end keeps its start time");
    ic = [event asICalComponent];
    start = icalcomponent_get_dtstart(ic);
    PASS(!start.is_date && icaltime_compare(start, icaltime_from_string("20240315T100000Z")) == 0,
	 "an event with a start time and no end is exported with its start time");
    PASS(icalcomponent_get_first_property(ic, ICAL_DTEND_PROPERTY) == NULL
	 && icalcomponent_get_first_property(ic, ICAL_DURATION_PROPERTY) == NULL,
	 "an event without duration is exported without end nor duration");
    icalcomponent_free(ic);

    /* It is an instant, shown on the day of each occurrence */
    event = eventFromString(VEVENT("DTSTART:20240315T100000\r\nRRULE:FREQ=WEEKLY;COUNT=3\r\n"));
    PASS([event isScheduledForDay:dt("20240315")] && [event isScheduledForDay:dt("20240322")]
	 && [event isScheduledForDay:dt("20240329")],
	 "an event without duration is scheduled on the days of its occurrences");
    PASS(![event isScheduledForDay:dt("20240316")] && ![event isScheduledForDay:dt("20240405")],
	 "an event without duration isn't scheduled on other days");
    PASS([event intersectionWithDay:dt("20240322")].location == 36000
	 && [event intersectionWithDay:dt("20240322")].length == 0,
	 "the intersection of an event without duration is empty, at its time");
    PASS([archived(event) duration] == 0 && ![archived(event) allDay],
	 "an archived event without duration stays without duration");
    event = eventFromString(VEVENT("DTSTART:20240315T000000\r\n"));
    PASS([event isScheduledForDay:dt("20240315")] && ![event isScheduledForDay:dt("20240314")],
	 "an event without duration at midnight is only scheduled on its day");
  }

  /*
   * Finding 4 : -setAllDay: made the start a date but kept its timezone,
   * which isn't archived. libical added the hours of a sub-daily rule
   * with DST, and without it once archived : occurrences could change day
   */
  {
    Event *e;

    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20230430T030000") duration:60 title:@"T"]);
    [e setAllDay:YES];
    PASS([[e startDate] isDate] && [[e startDate] localICalTime].zone == NULL,
	 "-setAllDay: gives a date without timezone");

    /* Made all day like the appointment editor does */
    event = eventFromString(VEVENT("DTSTART:20230430T030000\r\nDURATION:PT1H\r\n"
				   "RRULE:FREQ=HOURLY;INTERVAL=7456;COUNT=5\r\n"));
    [event setAllDay:YES];
    if (isDST("20230430T030000") != isDST("20251117T030000"))
      PASS_EQUAL(occurrences(archived(event), 10), occurrences(event, 10),
		 "an archived all day event with a sub-daily rule has the same occurrences");
  }

  /* libical problems */
  testHopeful = YES;

  /* Duplicate BYDAY values give duplicate occurrences, counted by COUNT */
  event = eventFromString(VEVENT("DTSTART:20240311T100000\r\nDURATION:PT1H\r\n"
				 "RRULE:FREQ=WEEKLY;COUNT=4;BYDAY=MO,MO,WE\r\n"));
  PASS_EQUAL(occurrences(event, 10),
	     @"20240311T100000 20240313T100000 20240318T100000 20240320T100000",
	     "duplicate BYDAY values don't give duplicate occurrences");

  /* A sub-daily rule on a date repeats the date */
  event = eventFromString(VEVENT("DTSTART;VALUE=DATE:20240101\r\nRRULE:FREQ=HOURLY;COUNT=3\r\n"));
  PASS(![occurrences(event, 10) isEqualToString:@"20240101 20240101 20240101"],
       "a sub-daily rule on an all day event doesn't repeat the same date");

  /*
   * BYWEEKNO : the fridays of weeks 1 and 5 are 20260102 (DTSTART),
   * 20260130, 20270108 and 20270205. libical gives 20261231 20260128
   * 20270106 20270203 : wrong days, not in order and without DTSTART.
   * As -intersectionWithDay: stops at the first occurrence after the day,
   * the event isn't even shown on its start day
   */
  event = eventFromString(VEVENT("DTSTART;VALUE=DATE:20260102\r\n"
				 "RRULE:FREQ=YEARLY;BYWEEKNO=1,5;COUNT=4\r\n"));
  PASS_EQUAL(occurrences(event, 10), @"20260102 20260130 20270108 20270205",
	     "BYWEEKNO gives the right occurrences");
  PASS([event isScheduledForDay:dt("20260102")],
       "an event with a BYWEEKNO rule is scheduled on its start day");
  PASS([event isScheduledForDay:dt("20260130")],
       "an event with a BYWEEKNO rule is scheduled on its occurrences");

  /*
   * An UNTIL in year 0 ends the rule before it starts, but
   * icalrecurrencetype_as_string() drops it : an archived rule never ends
   */
  event = eventFromString(VEVENT("DTSTART;VALUE=DATE:20240330\r\n"
				 "RRULE:FREQ=DAILY;UNTIL=00000406\r\n"));
  PASS_EQUAL(occurrences(archived(event), 3), occurrences(event, 3),
	     "an archived rule ending in year 0 has the same occurrences");

  testHopeful = NO;

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
