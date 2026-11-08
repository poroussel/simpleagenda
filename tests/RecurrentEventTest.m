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
#import "DateRange.h"
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
  NSEnumerator *enumerator = [event dateRangeEnumerator];
  DateRange *range;

  while ([dates count] < max && (range = [enumerator nextObject]))
    [dates addObject:[[range start] description]];
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
   * RSCALE (RFC 7529). struct icalrecurrencetype has a char *rscale
   * owned by the RRULE property value, and -initWithICalComponent: copies
   * the struct : the rule points into the component. -updateICalComponent:
   * deletes the RRULE property and then copies the rule, reading freed
   * memory (heap-use-after-free under AddressSanitizer)
   */
  testHopeful = YES;	/* Finding 1, not fixed yet */
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
  }
  testHopeful = NO;

  /*
   * A rule that never matches : the 53rd monday of a month. libical
   * looks for it for about a second, and the views call
   * -isScheduledForDay: for each day they show
   */
  testHopeful = YES;	/* Finding 2, not fixed yet */
  {
    NSDate *start;
    NSTimeInterval elapsed;

    event = eventFromString(VEVENT("DTSTART:20240101T080000Z\r\nDURATION:PT1H\r\n"
				   "RRULE:FREQ=MONTHLY;BYDAY=MO;BYSETPOS=53\r\n"));
    start = [NSDate date];
    [event isScheduledForDay:dt("20240102")];
    elapsed = -[start timeIntervalSinceNow];
    PASS(elapsed < 0.1,
	 "-isScheduledForDay: is fast for a rule without any occurrence (%.2fs)", elapsed);
  }
  testHopeful = NO;

  /*
   * RFC 5545 3.6.1 : a VEVENT with a DATE-TIME DTSTART and no DTEND or
   * DURATION ends at its start. SimpleAgenda makes it an all day event and
   * drops its time when it is saved
   */
  testHopeful = YES;	/* Finding 3, not fixed yet */
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
    icalcomponent_free(ic);
  }
  testHopeful = NO;

  /*
   * -setAllDay: makes the start a date but keeps its timezone, which
   * isn't archived. libical adds the hours of a sub-daily rule with DST,
   * and without it once archived : occurrences can change day
   */
  testHopeful = YES;	/* Finding 4, not fixed yet */
  {
    Event *e;

    e = AUTORELEASE([[Event alloc] initWithStartDate:dt("20230430T030000") duration:60 title:@"T"]);
    [e setAllDay:YES];
    PASS([[e startDate] isDate] && [[e startDate] localICalTime].zone == NULL,
	 "-setAllDay: gives a date without timezone");

    event = eventFromString(VEVENT("DTSTART:20230430T030000\r\n"
				   "RRULE:FREQ=HOURLY;INTERVAL=7456;COUNT=5\r\n"));
    if (isDST("20230430T030000") != isDST("20251117T030000"))
      PASS_EQUAL(occurrences(archived(event), 10), occurrences(event, 10),
		 "an archived all day event with a sub-daily rule has the same occurrences");
  }
  testHopeful = NO;

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
