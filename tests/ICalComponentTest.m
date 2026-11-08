/* -*- objc -*- */

#import "ObjectTesting.h"
#import "ICalComponent.h"
#import "Date+ICal.h"
#import "RecurrenceRule.h"

#define CRLF "\r\n"

/* Builds a date or a datetime in the local timezone from an iCalendar string */
static Date *dt(const char *string)
{
  return AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string(string)]);
}

static ICalComponent *parse(NSString *string)
{
  return [ICalComponent componentWithString:string];
}

static BOOL contains(ICalComponent *component, NSString *text)
{
  return [[component stringValue] rangeOfString:text].location != NSNotFound;
}

int main()
{
  CREATE_AUTORELEASE_POOL(arp);
  ICalComponent *cal, *ev, *alarm;
  NSTimeInterval duration;
  NSArray *children;

  /* Parsing and writing */
  PASS(parse(nil) == nil, "+componentWithString: nil gives nil");
  PASS(parse(@"") == nil, "+componentWithString: an empty string gives nil");
  PASS(parse(@"not a calendar") == nil, "+componentWithString: refuses text that isn't iCalendar");
  cal = parse(@"BEGIN:VCALENDAR" CRLF "VERSION:2.0" CRLF "PRODID:-//test//EN" CRLF
	      "BEGIN:VEVENT" CRLF "UID:1" CRLF "SUMMARY:One" CRLF "END:VEVENT" CRLF
	      "BEGIN:VTODO" CRLF "UID:2" CRLF "SUMMARY:Two" CRLF "END:VTODO" CRLF
	      "BEGIN:VEVENT" CRLF "UID:3" CRLF "SUMMARY:Three" CRLF "END:VEVENT" CRLF
	      "END:VCALENDAR" CRLF);
  PASS(cal != nil && [cal kind] == ICalVCalendar, "+componentWithString: parses a calendar");
  PASS([[cal componentsOfKind:ICalVEvent] count] == 2 && [[cal componentsOfKind:ICalVTodo] count] == 1,
       "-componentsOfKind: gives the components of a kind");
  PASS([[cal componentsOfKind:ICalVAlarm] count] == 0 && [[cal componentsOfKind:ICalOtherComponent] count] == 0,
       "-componentsOfKind: is empty for other kinds");
  ev = [[cal componentsOfKind:ICalVEvent] objectAtIndex:1];
  PASS([ev kind] == ICalVEvent && [[ev textForProperty:@"UID"] isEqualToString:@"3"],
       "the components are in order");
  PASS(contains(cal, @"BEGIN:VTODO\r\nUID:2\r\nSUMMARY:Two\r\nEND:VTODO\r\n"), "-stringValue writes iCalendar");
  PASS([ICalComponent componentWithKind:ICalOtherComponent] == nil, "+componentWithKind: refuses other kinds");
  ev = [ICalComponent componentWithKind:ICalVEvent];
  PASS([ev kind] == ICalVEvent && [[ev stringValue] isEqualToString:@"BEGIN:VEVENT\r\nEND:VEVENT\r\n"],
       "+componentWithKind: gives an empty component");

  /* Properties */
  ev = parse(@"BEGIN:VEVENT" CRLF "UID:1" CRLF "SUMMARY:First" CRLF "SUMMARY:Second" CRLF
	     "X-FOO;X-PARAM=1:foo" CRLF "X-BAR:bar" CRLF "X-FOO:foo2" CRLF
	     "ATTENDEE;CN=\"Doe, John\":mailto:j@d.c" CRLF "END:VEVENT" CRLF);
  PASS([ev hasProperty:@"SUMMARY"] && ![ev hasProperty:@"LOCATION"], "-hasProperty: works");
  PASS_EQUAL([ev textForProperty:@"SUMMARY"], @"First", "-textForProperty: gives the first property");
  PASS_EQUAL([ev textsForProperty:@"SUMMARY"], ([NSArray arrayWithObjects:@"First", @"Second", nil]),
	     "-textsForProperty: gives all the properties");
  PASS([ev textForProperty:@"LOCATION"] == nil, "-textForProperty: is nil without such a property");
  PASS_EQUAL([ev textsForProperty:@"X-FOO"], ([NSArray arrayWithObjects:@"foo", @"foo2", nil]),
	     "X- properties are found by their name");
  [ev setText:@"Third" forProperty:@"SUMMARY"];
  PASS_EQUAL([ev textsForProperty:@"SUMMARY"], ([NSArray arrayWithObjects:@"Second", @"Third", nil]),
	     "-setText:forProperty: replaces the first property, the new one goes last");
  [ev removeProperty:@"SUMMARY"];
  PASS_EQUAL([ev textsForProperty:@"SUMMARY"], [NSArray arrayWithObject:@"Third"],
	     "-removeProperty: removes the first property");
  [ev setText:nil forProperty:@"SUMMARY"];
  PASS(![ev hasProperty:@"SUMMARY"], "-setText:nil only removes the property");
  [ev removeAllProperties:@"X-FOO"];
  PASS(![ev hasProperty:@"X-FOO"] && [[ev textForProperty:@"X-BAR"] isEqualToString:@"bar"],
       "-removeAllProperties: removes all the properties with that name only");
  [ev setText:@"TRUE" forProperty:@"X-SIMPLEAGENDA-STICKY"];
  PASS(contains(ev, @"X-SIMPLEAGENDA-STICKY:TRUE\r\n"), "-setText:forProperty: writes X- properties");
  PASS(contains(ev, @"ATTENDEE;CN=\"Doe, John\":mailto:j@d.c\r\n"),
       "properties the model doesn't use are kept with their parameters");

  /* Text values */
  ev = [ICalComponent componentWithKind:ICalVEvent];
  [ev setText:@"a, b; c\\d\ne \303\251" forProperty:@"DESCRIPTION"];
  PASS(contains(ev, @"DESCRIPTION:a\\, b\\; c\\\\d\\ne \303\251\r\n"), "text values are escaped");
  PASS_EQUAL([ev textForProperty:@"DESCRIPTION"], @"a, b; c\\d\ne \303\251", "text values are unescaped");
  ev = parse([ev stringValue]);
  PASS_EQUAL([ev textForProperty:@"DESCRIPTION"], @"a, b; c\\d\ne \303\251", "escaped text values are read back");
  [ev setText:@"Idea,Travel" forProperty:@"CATEGORIES"];
  PASS_EQUAL([ev textForProperty:@"CATEGORIES"], @"Idea,Travel", "CATEGORIES is one text value");
  [ev setText:@"PRIVATE" forProperty:@"CLASS"];
  [ev setText:@"IN-PROCESS" forProperty:@"STATUS"];
  [ev setText:@"3" forProperty:@"REPEAT"];
  PASS(contains(ev, @"CLASS:PRIVATE\r\n") && contains(ev, @"STATUS:IN-PROCESS\r\n") && contains(ev, @"REPEAT:3\r\n"),
       "enumerated and integer values are written as given");
  PASS_EQUAL([parse(@"BEGIN:VEVENT" CRLF "CLASS:private" CRLF "END:VEVENT" CRLF) textForProperty:@"CLASS"],
	     @"PRIVATE", "enumerated values are read in upper case");
  [ev setText:@"" forProperty:@"CLASS"];
  PASS(contains(ev, @"CLASS:\r\n"), "an empty CLASS is written like libical's X and NONE values");
  [ev setText:@"value" forProperty:@"NOT-A-PROPERTY"];
  PASS(![ev hasProperty:@"NOT-A-PROPERTY"] && !contains(ev, @"NOT-A-PROPERTY"),
       "a property libical doesn't know isn't written");

  /* Dates, durations and rules */
  ev = parse(@"BEGIN:VEVENT" CRLF "DTSTART:20240615T100000Z" CRLF "DTEND:20240615T113000Z" CRLF
	     "DUE;VALUE=DATE:20240620" CRLF "DURATION:PT1H30M" CRLF "RRULE:FREQ=WEEKLY;COUNT=3" CRLF "END:VEVENT" CRLF);
  PASS([[ev dateForProperty:@"DTSTART"] isEqual:dt("20240615T100000Z")]
       && ![[ev dateForProperty:@"DTSTART"] isDate], "-dateForProperty: reads datetimes");
  PASS([[ev dateForProperty:@"DUE"] isDate] && [[[ev dateForProperty:@"DUE"] description] isEqualToString:@"20240620"],
       "-dateForProperty: reads dates");
  PASS([ev dateForProperty:@"DTSTAMP"] == nil, "-dateForProperty: is nil without such a property");
  PASS([ev secondsFromProperty:@"DTSTART" toProperty:@"DTEND"] == 5400, "-secondsFromProperty:toProperty: works");
  PASS([ev getDuration:&duration forProperty:@"DURATION"] && duration == 5400, "-getDuration:forProperty: works");
  PASS(![ev getDuration:&duration forProperty:@"TRIGGER"], "-getDuration:forProperty: is NO without such a property");
  PASS([[ev ruleForProperty:@"RRULE"] count] == 3, "-ruleForProperty: works");
  [ev setDate:dt("20240616T120000Z") forProperty:@"DTSTART"];
  PASS(contains(ev, @"DTSTART:20240616T120000Z\r\n"), "-setDate:forProperty: writes datetimes in UTC");
  [ev setDate:dt("20240621") forProperty:@"DUE"];
  PASS(contains(ev, @"DUE;VALUE=DATE:20240621\r\n"), "-setDate:forProperty: writes dates");
  [ev setDate:dt("20240616T120000Z") plusSeconds:3600 forProperty:@"DTEND"];
  PASS(contains(ev, @"DTEND:20240616T130000Z\r\n"), "-setDate:plusSeconds:forProperty: works");
  [ev setDuration:600 forProperty:@"DURATION"];
  PASS(contains(ev, @"DURATION:PT10M\r\n"), "-setDuration:forProperty: works");
  [ev setRule:AUTORELEASE([[RecurrenceRule alloc] initWithString:@"FREQ=DAILY;COUNT=2"]) forProperty:@"RRULE"];
  PASS(contains(ev, @"RRULE:FREQ=DAILY;COUNT=2\r\n"), "-setRule:forProperty: works");
  [ev setRule:nil forProperty:@"RRULE"];
  PASS(![ev hasProperty:@"RRULE"], "-setRule:nil removes the rule");
  [ev setDate:nil forProperty:@"DTSTAMP"];
  PASS(contains(ev, @"DTSTAMP:00000000T000000\r\n"), "-setDate:nil writes a null date");

  /* Triggers are a duration or a date */
  alarm = [ICalComponent componentWithKind:ICalVAlarm];
  [alarm setDuration:-900 forProperty:@"TRIGGER"];
  PASS(contains(alarm, @"TRIGGER:-PT15M\r\n"), "a relative trigger is written as a duration");
  PASS([alarm dateForProperty:@"TRIGGER"] == nil, "a relative trigger has no date");
  PASS([alarm getDuration:&duration forProperty:@"TRIGGER"] && duration == -900, "a relative trigger has a duration");
  [alarm setDate:dt("20240615T093000Z") forProperty:@"TRIGGER"];
  PASS(contains(alarm, @"TRIGGER;VALUE=DATE-TIME:20240615T093000Z\r\n"), "an absolute trigger is written as a date");
  PASS([[alarm dateForProperty:@"TRIGGER"] isEqual:dt("20240615T093000Z")], "an absolute trigger has a date");
  PASS([alarm getDuration:&duration forProperty:@"TRIGGER"] && duration == 0, "an absolute trigger has no duration");

  /* Components : copies, adding and removing */
  ev = [ICalComponent componentWithKind:ICalVEvent];
  [ev setText:@"1" forProperty:@"UID"];
  alarm = [ICalComponent componentWithKind:ICalVAlarm];
  [alarm setText:@"DISPLAY" forProperty:@"ACTION"];
  [ev addComponent:alarm];
  PASS([[ev componentsOfKind:ICalVAlarm] count] == 1 && contains(ev, @"BEGIN:VALARM\r\nACTION:DISPLAY\r\nEND:VALARM"),
       "-addComponent: works");
  PASS_EXCEPTION([ev addComponent:alarm], NSInternalInconsistencyException,
		 "-addComponent: refuses a component that already has a parent");
  {
    ICalComponent *copy = AUTORELEASE([ev copy]);

    [copy setText:@"2" forProperty:@"UID"];
    PASS([[ev textForProperty:@"UID"] isEqualToString:@"1"] && [[copy componentsOfKind:ICalVAlarm] count] == 1,
	 "-copy copies the whole component");
  }
  children = [ev componentsOfKind:ICalVAlarm];
  [ev removeComponent:[children objectAtIndex:0]];
  PASS([[ev componentsOfKind:ICalVAlarm] count] == 0, "-removeComponent: works");
  PASS([[[children objectAtIndex:0] textForProperty:@"ACTION"] isEqualToString:@"DISPLAY"],
       "a removed component can still be used");
  PASS_EXCEPTION([ev removeComponent:[children objectAtIndex:0]], NSInternalInconsistencyException,
		 "-removeComponent: refuses a component that isn't a child");
  [ev addComponent:[children objectAtIndex:0]];
  PASS([[ev componentsOfKind:ICalVAlarm] count] == 1, "a removed component can be added again");

  /* A child keeps its tree alive */
  {
    ICalComponent *child;

    {
      CREATE_AUTORELEASE_POOL(pool);
      child = RETAIN([[parse(@"BEGIN:VCALENDAR" CRLF "BEGIN:VEVENT" CRLF "UID:kept" CRLF "END:VEVENT" CRLF
			     "END:VCALENDAR" CRLF) componentsOfKind:ICalVEvent] lastObject]);
      RELEASE(pool);
    }
    PASS_EQUAL([child textForProperty:@"UID"], @"kept", "a child can be used when its tree isn't referenced anymore");
    RELEASE(child);
  }

  /* Errors */
  cal = parse(@"BEGIN:VCALENDAR" CRLF "BEGIN:VEVENT" CRLF "DTSTART:garbage" CRLF "END:VEVENT" CRLF "END:VCALENDAR" CRLF);
  PASS(contains(cal, @"X-LIC-ERROR"), "libical marks invalid values");
  [cal removeErrors];
  PASS(!contains(cal, @"X-LIC-ERROR"), "-removeErrors removes the marks");

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
