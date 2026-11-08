/* -*- objc -*- */

#import "ObjectTesting.h"
#import "RecurrenceRule.h"

/* Builds a date or a datetime in the local timezone from an iCalendar string */
static Date *dt(const char *string)
{
  return AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string(string)]);
}

/* Compares what the enumerator returns to a list of dates separated by spaces */
static BOOL sameDates(NSEnumerator *enumerator, const char *expected)
{
  NSMutableArray *dates = [NSMutableArray array];
  Date *date;

  while ((date = [enumerator nextObject]))
    [dates addObject:[date description]];
  return [[dates componentsJoinedByString:@" "]
	   isEqualToString:[NSString stringWithUTF8String:expected]];
}

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  int count = 0;
  Date *tmp;
  NSEnumerator *enumerator;

  test_alloc(@"RecurrenceRule");

  RecurrenceRule *rule = [[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceYearly count:3];

  enumerator = [rule enumeratorFromDate:[Date today]];
  while ((tmp = [enumerator nextObject])) {
    count++;
    PASS([tmp isDate], "Recurrence enumerators return dates.");
  }
  PASS(count == 3, "Iterator should return only 3 dates.");

  test_NSObject(@"RecurrenceRule", [NSArray arrayWithObject:rule]);
  /*
   * test_keyed_NSCoding() can't be used : RecurrenceRule implements the
   * NSCoding methods without declaring the protocol.
   */

  [rule release];

  /* Accessors */
  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily]);
  PASS([rule frequency] == recurrenceFrequenceDaily, "-initWithFrequency: works");
  PASS([rule count] == 0, "no count by default");
  PASS([rule until] == nil, "no end date by default");

  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceMonthly count:7]);
  PASS([rule frequency] == recurrenceFrequenceMonthly && [rule count] == 7,
       "-initWithFrequency:count: works");
  PASS([rule until] == nil, "-initWithFrequency:count: has no end date");

  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceWeekly until:dt("20240630")]);
  PASS([rule frequency] == recurrenceFrequenceWeekly, "-initWithFrequency:until: sets the frequency");
  PASS([rule count] == 0, "-initWithFrequency:until: has no count");
  PASS([[rule until] compare:dt("20240630") withTime:NO] == NSOrderedSame
       && [[rule until] isDate], "-until returns the end date");

  /* Invalid arguments */
  PASS_EXCEPTION(AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceOther]),
		 NSInternalInconsistencyException,
		 "-initWithFrequency: refuses recurrenceFrequenceOther");
  PASS_EXCEPTION(AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceOther count:1]),
		 NSInternalInconsistencyException,
		 "-initWithFrequency:count: refuses recurrenceFrequenceOther");
  PASS_EXCEPTION(AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceOther until:dt("20240630")]),
		 NSInternalInconsistencyException,
		 "-initWithFrequency:until: refuses recurrenceFrequenceOther");
  PASS_EXCEPTION(AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily until:dt("20240630T100000")]),
		 NSInternalInconsistencyException,
		 "-initWithFrequency:until: refuses a datetime");

  /* Each frequency gives the expected dates */
  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily count:3]);
  PASS(sameDates([rule enumeratorFromDate:dt("20240228")], "20240228 20240229 20240301"),
       "daily rule, across a leap day");
  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceWeekly count:3]);
  PASS(sameDates([rule enumeratorFromDate:dt("20241224")], "20241224 20241231 20250107"),
       "weekly rule, across a year");
  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceMonthly count:3]);
  PASS(sameDates([rule enumeratorFromDate:dt("20241115")], "20241115 20241215 20250115"),
       "monthly rule, across a year");
  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceYearly count:3]);
  PASS(sameDates([rule enumeratorFromDate:dt("20240615")], "20240615 20250615 20260615"),
       "yearly rule");

  /* An end date is included */
  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily until:dt("20240617")]);
  PASS(sameDates([rule enumeratorFromDate:dt("20240615")], "20240615 20240616 20240617"),
       "a rule stops on its end date");
  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceWeekly until:dt("20240630")]);
  PASS(sameDates([rule enumeratorFromDate:dt("20240615")], "20240615 20240622 20240629"),
       "a rule stops before its end date if no date matches");

  /* A rule without limit goes on */
  {
    NSEnumerator *e;
    int i;

    rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily]);
    e = [rule enumeratorFromDate:dt("20240615")];
    for (i = 0; i < 1000 && [e nextObject]; i++)
      ;
    PASS(i == 1000, "a rule without limit doesn't stop");
  }

  /* Datetimes */
  {
    NSEnumerator *e;
    Date *date;
    NSUInteger n = 0;

    rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily count:2]);
    e = [rule enumeratorFromDate:dt("20240615T143000")];
    while ((date = [e nextObject])) {
      n++;
      PASS([date isKindOfClass:[Date class]], "the enumerator returns dates");
      PASS(![date isDate] && [date minuteOfDay] == 870,
	   "the occurrences of a datetime are at its time");
      PASS([date dayOfMonth] == (int)(14 + n), "the occurrences of a datetime follow the rule");
    }
    PASS(n == 2, "the enumerator of datetimes stops at the end of the rule");
  }

  /* iCalendar */
  {
    struct icalrecurrencetype rrule = icalrecurrencetype_from_string("FREQ=WEEKLY;COUNT=3;BYDAY=MO,WE");
    struct icalrecurrencetype back;

    rule = AUTORELEASE([[RecurrenceRule alloc] initWithICalRRule:rrule]);
    PASS([rule frequency] == recurrenceFrequenceWeekly && [rule count] == 3,
	 "-initWithICalRRule: works");
    /* 2024-06-17 is a monday */
    PASS(sameDates([rule enumeratorFromDate:dt("20240617")], "20240617 20240619 20240624"),
	 "the rules libical understands are taken into account");
    back = [rule iCalRRule];
    PASS(back.freq == ICAL_WEEKLY_RECURRENCE && back.count == 3
	 && back.by_day[0] != ICAL_RECURRENCE_ARRAY_MAX, "-iCalRRule returns the rule");
  }

  /* NSCoding */
  {
    RecurrenceRule *decoded;

    rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceWeekly count:5]);
    decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
				   [NSKeyedArchiver archivedDataWithRootObject:rule]];
    PASS(decoded != nil && [decoded frequency] == recurrenceFrequenceWeekly && [decoded count] == 5,
	 "NSCoding preserves a rule with a count");
    rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceDaily until:dt("20240617")]);
    decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
				   [NSKeyedArchiver archivedDataWithRootObject:rule]];
    PASS(decoded != nil && [decoded frequency] == recurrenceFrequenceDaily
	 && [decoded until] != nil && [[decoded until] compare:dt("20240617") withTime:NO] == NSOrderedSame,
	 "NSCoding preserves a rule with an end date");
    PASS(sameDates([decoded enumeratorFromDate:dt("20240616")], "20240616 20240617"),
	 "a decoded rule gives the same dates");
  }

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
