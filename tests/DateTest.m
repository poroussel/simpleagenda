/* -*- objc -*- */

#import "ObjectTesting.h"
#import "Date+ICal.h"
#import <math.h>

/* Builds a date or a datetime in the local timezone from an iCalendar string */
static Date *dt(const char *string)
{
  return AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string(string)]);
}

/* Writes the same keys as -[Date encodeWithCoder:], to build the archive
 * a Date would have written in another timezone */
@interface ArchivedDate : NSObject
{
  NSString *_icalTime;
  NSString *_timezone;
}
@end
@implementation ArchivedDate
+ (Date *)decodeTime:(NSString *)time timezone:(NSString *)tzid
{
  ArchivedDate *a = AUTORELEASE([ArchivedDate new]);
  NSKeyedArchiver *archiver;
  NSMutableData *data = [NSMutableData data];

  a->_icalTime = time;
  a->_timezone = tzid;
  archiver = AUTORELEASE([[NSKeyedArchiver alloc] initForWritingWithMutableData:data]);
  [archiver setClassName:@"Date" forClass:[ArchivedDate class]];
  [archiver encodeObject:a forKey:@"root"];
  [archiver finishEncoding];
  return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}
- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_icalTime forKey:@"icalTime"];
  if (_timezone)
    [coder encodeObject:_timezone forKey:@"timezone"];
}
@end

static BOOL sameICalTime(struct icaltimetype a, struct icaltimetype b)
{
  return a.year == b.year && a.month == b.month && a.day == b.day &&
    a.hour == b.hour && a.minute == b.minute && a.second == b.second;
}

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

  /* Field accessors on a fixed datetime : saturday 2024-06-15 14:30:45 */
  Date *fixed = dt("20240615T143045");
  PASS([fixed year] == 2024 && [fixed monthOfYear] == 6 && [fixed dayOfMonth] == 15,
       "-year, -monthOfYear and -dayOfMonth work");
  PASS([fixed hourOfDay] == 14 && [fixed minuteOfHour] == 30 && [fixed secondOfMinute] == 45,
       "-hourOfDay, -minuteOfHour and -secondOfMinute work");
  PASS([fixed minuteOfDay] == 870, "-minuteOfDay works");
  PASS(![fixed isDate], "a value with a time isn't a date");
  PASS([dt("20240615") isDate], "a value without a time is a date");
  PASS_EQUAL([fixed description], @"20240615T143045", "-description works");
  PASS_EQUAL([dt("20240615") description], @"20240615", "-description of a date works");

  /* Weekdays go from 1 (monday) to 7 (sunday) */
  PASS([dt("20240610") weekday] == 1, "a monday is day 1");
  PASS([dt("20240615") weekday] == 6, "a saturday is day 6");
  PASS([dt("20240616") weekday] == 7, "a sunday is day 7");

  /* ISO 8601 weeks */
  PASS([dt("20240101") weekOfYear] == 1, "2024-01-01 is in week 1");
  PASS([dt("20240615") weekOfYear] == 24, "2024-06-15 is in week 24");
  PASS([dt("20241230") weekOfYear] == 1, "2024-12-30 is in week 1 of the next year");
  PASS([dt("20210103") weekOfYear] == 53, "2021-01-03 is in week 53 of the previous year");

  /* Number of days in month */
  PASS([dt("20240115") numberOfDaysInMonth] == 31, "January has 31 days");
  PASS([dt("20240415") numberOfDaysInMonth] == 30, "April has 30 days");
  PASS([dt("20240215") numberOfDaysInMonth] == 29, "February 2024 has 29 days");
  PASS([dt("20230215") numberOfDaysInMonth] == 28, "February 2023 has 28 days");
  PASS([dt("19000215") numberOfDaysInMonth] == 28, "February 1900 has 28 days");
  PASS([dt("20000215") numberOfDaysInMonth] == 29, "February 2000 has 29 days");

  /* Setters */
  Date *d = dt("20240615T143045");
  [d setSecondOfMinute:10];
  PASS([d secondOfMinute] == 10 && [d minuteOfHour] == 30, "-setSecondOfMinute: works");
  [d setSecondOfMinute:70];
  PASS([d secondOfMinute] == 10 && [d minuteOfHour] == 31,
       "-setSecondOfMinute: normalizes the time");

  d = dt("20240615T143000");
  [d setMinute:60];
  PASS([d minuteOfDay] == 60 && [d dayOfMonth] == 15,
       "-setMinute: sets the minute of the day, backward");
  [d setMinute:1000];
  PASS([d minuteOfDay] == 1000 && [d dayOfMonth] == 15,
       "-setMinute: sets the minute of the day, forward");
  PASS_EXCEPTION([dt("20240615") setMinute:10], NSInternalInconsistencyException,
		 "-setMinute: raises an exception on a date");
  PASS_EXCEPTION([dt("20240615") setSecondOfMinute:10], NSInternalInconsistencyException,
		 "-setSecondOfMinute: raises an exception on a date");

  d = dt("20240131");
  [d setDay:32];
  PASS([d monthOfYear] == 2 && [d dayOfMonth] == 1, "-setDay: normalizes the date");
  d = dt("20240615");
  [d setMonth:13];
  PASS([d year] == 2025 && [d monthOfYear] == 1, "-setMonth: normalizes the date");
  d = dt("20240615");
  [d setYear:2030];
  PASS([d year] == 2030 && [d monthOfYear] == 6 && [d dayOfMonth] == 15, "-setYear: works");

  d = dt("20240229");
  [d setYear:2023];
  PASS([d monthOfYear] == 3 && [d dayOfMonth] == 1,
       "-setYear: on february 29th doesn't give an invalid date");
  d = dt("20240229");
  [d changeYearBy:1];
  PASS([d monthOfYear] == 3 && [d dayOfMonth] == 1,
       "-changeYearBy: on february 29th doesn't give an invalid date");

  /* Relative changes */
  d = dt("20241231");
  [d incrementDay];
  PASS([d year] == 2025 && [d monthOfYear] == 1 && [d dayOfMonth] == 1,
       "-incrementDay works across years");
  d = dt("20240301");
  [d changeDayBy:-1];
  PASS([d monthOfYear] == 2 && [d dayOfMonth] == 29,
       "-changeDayBy: with a negative value works across months");
  d = dt("20240228");
  [d changeDayBy:2];
  PASS([d monthOfYear] == 3 && [d dayOfMonth] == 1,
       "-changeDayBy: with a positive value works across months");
  d = dt("20240615");
  [d changeYearBy:-4];
  PASS([d year] == 2020, "-changeYearBy: works");
  d = dt("20240615T233000");
  [d changeMinuteBy:45];
  PASS([d dayOfMonth] == 16 && [d minuteOfDay] == 15,
       "-changeMinuteBy: with a positive value works across days");
  [d changeMinuteBy:-45];
  PASS([d dayOfMonth] == 15 && [d minuteOfDay] == 1410,
       "-changeMinuteBy: with a negative value works across days");

  /* -setIsDate: */
  d = dt("20240615T143045");
  [d setIsDate:NO];
  PASS(![d isDate] && [d minuteOfDay] == 870, "-setIsDate:NO keeps the time");
  [d setIsDate:YES];
  [d setIsDate:NO];
  PASS(![d isDate] && [d minuteOfDay] == 0 && [d secondOfMinute] == 0,
       "-setIsDate:YES resets the time");

  /* Comparisons */
  PASS([fixed isEqual:nil] == NO, "-isEqual:nil returns NO");
  PASS([fixed isEqual:fixed] == YES, "-isEqual: returns YES for the same object");
  PASS([dt("20240615") compare:dt("20240616") withTime:NO] == NSOrderedAscending,
       "-compare:withTime:NO on days");
  PASS([dt("20240715") compare:dt("20240616") withTime:NO] == NSOrderedDescending,
       "-compare:withTime:NO on months");
  PASS([dt("20230715") compare:dt("20240616") withTime:NO] == NSOrderedAscending,
       "-compare:withTime:NO on years");
  PASS([dt("20240615T100000") compare:dt("20240615T230000") withTime:NO] == NSOrderedSame,
       "-compare:withTime:NO ignores the time");
  PASS([dt("20240615T230000") compare:dt("20240615T100000") withTime:YES] == NSOrderedDescending,
       "-compare:withTime:YES uses the time");
  PASS([dt("20240615T100000") compare:dt("20240615T100000") withTime:YES] == NSOrderedSame,
       "-compare:withTime:YES on the same time");
  Date *dateFlag = dt("20240615");
  [dateFlag compare:dt("20240615T100000") withTime:YES];
  PASS([dateFlag isDate], "-compare:withTime: doesn't change the date flag");
  PASS_EXCEPTION([fixed compare:fixed], NSInvalidArgumentException, "-compare: isn't implemented");

  /* Equality and hash */
  PASS([dt("20240615T100000") isEqual:dt("20240615T100000")], "-isEqual: on the same time");
  PASS(![dt("20240615T100000") isEqual:dt("20240615T100001")], "-isEqual: on different times");
  PASS([dt("20240615T100000") hash] == [dt("20240615T100000") hash],
       "equal objects have the same hash");

  /* Factory methods */
  Date *source = dt("20240615T143045");
  d = [Date dayWithDate:source];
  PASS([d isDate] && [d dayOfMonth] == 15 && [d minuteOfDay] == 0,
       "+dayWithDate: returns the day of the date");
  PASS(![source isDate] && [source minuteOfDay] == 870,
       "+dayWithDate: doesn't modify the source date");

  d = AUTORELEASE([source copy]);
  [d changeDayBy:1];
  PASS([source dayOfMonth] == 15, "a copy is independent from the original");

  NSCalendarDate *cd = [NSCalendarDate dateWithYear:2024 month:6 day:15 hour:14 minute:30
					     second:45 timeZone:[NSTimeZone defaultTimeZone]];
  d = [Date dateWithCalendarDate:cd withTime:YES];
  PASS(![d isDate] && [d year] == 2024 && [d monthOfYear] == 6 && [d dayOfMonth] == 15
       && [d minuteOfDay] == 870 && [d secondOfMinute] == 45,
       "+dateWithCalendarDate:withTime:YES keeps the time");
  d = [Date dateWithCalendarDate:cd withTime:NO];
  PASS([d isDate] && [d dayOfMonth] == 15 && [d minuteOfDay] == 0 && [d secondOfMinute] == 0,
       "+dateWithCalendarDate:withTime:NO removes the time");

  source = dt("20240615T233000");
  d = [Date dateWithTimeInterval:3600 sinceDate:source];
  PASS([d dayOfMonth] == 16 && [d minuteOfDay] == 30 && ![d isDate],
       "+dateWithTimeInterval:sinceDate: forward");
  PASS([source dayOfMonth] == 15, "+dateWithTimeInterval:sinceDate: keeps the source date");
  d = [Date dateWithTimeInterval:-3600 sinceDate:source];
  PASS([d minuteOfDay] == 1350, "+dateWithTimeInterval:sinceDate: backward");
  d = [Date dateWithTimeInterval:1800 sinceDate:source];
  PASS([d dayOfMonth] == 16 && [d isDate], "a result falling on midnight is a date");
  PASS([[Date dateWithTimeInterval:86400 sinceDate:dt("20240615")] isDate],
       "adding whole days to a date gives a date");

  /* Time intervals */
  PASS([dt("20240615T100000") timeIntervalSinceDate:dt("20240615T090000")] == 3600,
       "-timeIntervalSinceDate: is positive for a later date");
  PASS([dt("20240615T090000") timeIntervalSinceDate:dt("20240615T100000")] == -3600,
       "-timeIntervalSinceDate: is negative for an earlier date");
  PASS([dt("20240616T100000") timeIntervalSince1970]
       - [dt("20240615T100000") timeIntervalSince1970] == 86400,
       "-timeIntervalSince1970 works");
  d = [Date dateWithTimeInterval:600 sinceDate:[Date now]];
  PASS(fabs([d timeIntervalSinceNow] - 600) < 5, "-timeIntervalSinceNow works");

  /* Date enumerators */
  int count = 0;
  enumerator = [dt("20240615T143000") enumeratorTo:dt("20240615T150000")];
  while ((tmp = [enumerator nextObject]))
    count++;
  PASS(count == 1, "an enumerator on one day returns one date");
  count = 0;
  enumerator = [dt("20240228") enumeratorTo:dt("20240301")];
  while ((tmp = [enumerator nextObject]))
    count++;
  PASS(count == 3, "an enumerator includes both bounds and leap days");
  enumerator = [dt("20240616") enumeratorTo:dt("20240615")];
  PASS([enumerator nextObject] == nil, "an enumerator with an end before the start is empty");

  /* NSCoding */
  Date *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
				       [NSKeyedArchiver archivedDataWithRootObject:fixed]];
  PASS(![decoded isDate] && [decoded compare:fixed withTime:YES] == NSOrderedSame,
       "NSCoding preserves a datetime");
  decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
				 [NSKeyedArchiver archivedDataWithRootObject:dt("20240615")]];
  PASS([decoded isDate] && [decoded compare:dt("20240615") withTime:NO] == NSOrderedSame,
       "NSCoding preserves a date");
  [decoded changeDayBy:0];
  PASS([[decoded description] isEqualToString:@"20240615"], "a decoded date is usable");

  /* iCalendar conversions */
  struct icaltimetype utc = [fixed UTCICalTime];
  PASS(icaltime_is_utc(utc), "-UTCICalTime returns an UTC time");
  decoded = AUTORELEASE([[Date alloc] initWithICalTime:utc]);
  PASS([decoded compare:fixed withTime:YES] == NSOrderedSame
       && [decoded minuteOfDay] == [fixed minuteOfDay],
       "-initWithICalTime: converts an UTC time to the local timezone");
  PASS(icaltime_is_date([dt("20240615") UTCICalTime]) &&
       [[AUTORELEASE([[Date alloc] initWithICalTime:[dt("20240615") UTCICalTime]]) description]
	 isEqualToString:@"20240615"],
       "a date isn't changed by timezone conversions");
  decoded = AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string("20240615T120000Z")]);
  PASS(icaltime_compare([decoded UTCICalTime], icaltime_from_string("20240615T120000Z")) == 0,
       "a fixed UTC instant is kept");

  /* Out of range fields : libical's parser accepts them (for example
   * DTSTART;VALUE=DATE:20262311) and only normalizes times it converts
   * between timezones, which leaves dates and floating times untouched */
  Date *month23 = dt("20262311");
  PASS([month23 year] == 2027 && [month23 monthOfYear] == 11 && [month23 dayOfMonth] == 11,
       "a date with month 23 is normalized");
  PASS_EQUAL([month23 description], @"20271111", "a date with month 23 is described normalized");
  /* libical returns 30 for any month outside 1-12 : use one that isn't 30 days long */
  PASS([dt("20261410") numberOfDaysInMonth] == 28, "a date with month 14 has the days of february");
  PASS([month23 isEqual:dt("20271111")], "a date with month 23 is equal to its normalized date");
  PASS([month23 hash] == [dt("20271111") hash],
       "a date with month 23 has the hash of its normalized date");
  PASS([month23 compare:dt("20271111") withTime:NO] == NSOrderedSame,
       "a date with month 23 compares as its normalized date without time");
  PASS(![month23 isEqual:dt("20261399")], "dates with different out of range fields are different");
  PASS([dt("20261399") isEqual:dt("20270409")], "january 99th is april 9th");
  PASS([[month23 calendarDate] monthOfYear] == 11, "-calendarDate works for a date with month 23");
  PASS([month23 weekOfYear] == [dt("20271111") weekOfYear], "-weekOfYear works for a date with month 23");

  Date *feb30 = dt("20260230T120000");
  PASS([feb30 monthOfYear] == 3 && [feb30 dayOfMonth] == 2 && [feb30 hourOfDay] == 12,
       "a floating datetime on february 30th is normalized");
  PASS([feb30 isEqual:dt("20260302T120000")],
       "a floating datetime on february 30th is equal to march 2nd");
  PASS([feb30 compare:dt("20260302T120000") withTime:NO] == NSOrderedSame,
       "february 30th compares as march 2nd without time");
  PASS([feb30 timeIntervalSinceDate:dt("20260301T120000")] == 86400,
       "february 30th is one day after march 1st");

  Date *hour25 = dt("20260615T253000");
  PASS([hour25 dayOfMonth] == 16 && [hour25 hourOfDay] == 1 && [hour25 minuteOfHour] == 30,
       "a floating datetime at 25:30 is normalized");
  PASS([hour25 minuteOfDay] == 90, "-minuteOfDay is less than a day for a datetime at 25:30");
  /* 2026-11-45 25:30 UTC is 2026-12-16 01:30 UTC, whatever the local timezone */
  PASS([dt("20261145T253000Z") isEqual:dt("20261216T013000Z")]
       && [dt("20261145T253000Z") hourOfDay] == [dt("20261216T013000Z") hourOfDay],
       "an UTC datetime with out of range fields is normalized");

  /* NSCoding and timezones. Dates are kept in the local timezone in memory.
   * -encodeWithCoder: writes the full timezone id
   * (/freeassociation.sourceforge.net/Europe/Paris), -initWithCoder: must
   * find it and convert the decoded datetime to the local timezone. */
  START_SET("NSCoding and timezones")
    icaltimezone *local = (icaltimezone *)[fixed localICalTime].zone;
    const char *other;

    /* Without a libical timezone (e.g. GNUstep calls UTC GMT+0000),
     * Date only uses floating times */
    if (local == NULL)
      SKIP("libical has no timezone matching the local timezone");
    other = strstr(icaltimezone_get_tzid(local), "Asia/Tokyo") ? "America/New_York" : "Asia/Tokyo";
    icaltimezone *otherZone = icaltimezone_get_builtin_timezone(other);
    /* 2024-06-15 12:00 UTC, in the other timezone */
    struct icaltimetype instant = icaltime_from_string("20240615T120000Z");
    NSString *otherTime = [NSString stringWithUTF8String:
      icaltime_as_ical_string(icaltime_convert_to_zone(instant, otherZone))];
    Date *expected = AUTORELEASE([[Date alloc] initWithICalTime:instant]);

    decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
				   [NSKeyedArchiver archivedDataWithRootObject:fixed]];
    PASS([decoded localICalTime].zone == local,
	 "a decoded datetime is in the local timezone");
    PASS(sameICalTime([decoded UTCICalTime], [fixed UTCICalTime]),
	 "a decoded datetime has the same UTC time as the archived one");
    PASS(icaltime_compare([decoded UTCICalTime], icaltime_from_string("20240615T143045Z")) != 0
	 || icaltimezone_get_utc_offset(local, &instant, NULL) == 0,
	 "a decoded datetime isn't read as UTC");

    /* Archive written by a Date in another timezone, as Date writes it */
    decoded = [ArchivedDate decodeTime:otherTime
			      timezone:[NSString stringWithUTF8String:icaltimezone_get_tzid(otherZone)]];
    PASS([decoded compare:expected withTime:YES] == NSOrderedSame,
	 "a datetime archived in another timezone compares as the same instant");
    PASS(sameICalTime([decoded UTCICalTime], instant),
	 "a datetime archived in another timezone keeps its UTC time");
    PASS([decoded localICalTime].zone == local,
	 "a datetime archived in another timezone is decoded in the local timezone");
    PASS([decoded hourOfDay] == [expected hourOfDay] && [decoded dayOfMonth] == [expected dayOfMonth],
	 "a datetime archived in another timezone shows the local hour");
    PASS([decoded isEqual:expected],
	 "a datetime archived in another timezone is equal to the same local instant");
    PASS([decoded hash] == [expected hash],
	 "a datetime archived in another timezone has the hash of the same local instant");

    /* Same archive with a location instead of a tzid : found by
     * icaltimezone_get_builtin_timezone(), but kept instead of converted */
    decoded = [ArchivedDate decodeTime:otherTime timezone:[NSString stringWithUTF8String:other]];
    PASS(sameICalTime([decoded UTCICalTime], instant),
	 "a datetime archived with a timezone location keeps its UTC time");
    PASS([decoded localICalTime].zone == local,
	 "a datetime archived with a timezone location is decoded in the local timezone");
    PASS([decoded isEqual:expected],
	 "a datetime archived with a timezone location is equal to the same local instant");

    /* Dates have no timezone : the day must not change */
    decoded = [ArchivedDate decodeTime:@"20240615" timezone:nil];
    PASS([decoded isDate] && [[decoded description] isEqualToString:@"20240615"],
	 "a date archived without timezone keeps its day");
  END_SET("NSCoding and timezones")

  /* Dates have no timezone, datetimes are in the local timezone */
  {
    const icaltimezone *local = [[Date now] localICalTime].zone;
    Date *d;

    d = [Date now];
    [d setIsDate:YES];
    PASS([d isDate] && [d localICalTime].zone == NULL, "-setIsDate:YES removes the timezone");
    [d setIsDate:NO];
    PASS(![d isDate] && [d localICalTime].zone == local,
	 "-setIsDate:NO on a date gives a datetime in the local timezone");
    PASS([Date today] != nil && [[Date today] localICalTime].zone == NULL, "+today has no timezone");
    PASS([[Date dayWithDate:[Date now]] localICalTime].zone == NULL, "+dayWithDate: has no timezone");
    d = [Date dateWithCalendarDate:[NSCalendarDate calendarDate] withTime:NO];
    PASS([d isDate] && [d localICalTime].zone == NULL,
	 "+dateWithCalendarDate:withTime:NO has no timezone");
    d = [Date dateWithCalendarDate:[NSCalendarDate calendarDate] withTime:YES];
    PASS(![d isDate] && [d localICalTime].zone == local,
	 "+dateWithCalendarDate:withTime:YES is in the local timezone");
    d = [Date dateWithTimeInterval:86400 sinceDate:dt("20240615")];
    PASS([d isDate] && [d localICalTime].zone == NULL && [[d description] isEqualToString:@"20240616"],
	 "+dateWithTimeInterval:sinceDate: of a whole day gives a date without timezone");
    d = [Date dateWithTimeInterval:3600 sinceDate:dt("20240615")];
    PASS(![d isDate] && [d localICalTime].zone == local && [[d description] isEqualToString:@"20240615T010000"],
	 "+dateWithTimeInterval:sinceDate: of an hour gives a local datetime");
    {
      icaltimezone *paris = icaltimezone_get_builtin_timezone("Europe/Paris");
      struct icaltimetype t = icaltime_from_string("20240615");

      t = icaltime_set_timezone(&t, paris);
      d = AUTORELEASE([[Date alloc] initWithICalTime:t]);
      PASS([d isDate] && [d localICalTime].zone == NULL && [[d description] isEqualToString:@"20240615"],
	   "-initWithICalTime: drops the timezone of a date");
    }

    /* A date compares as the local midnight */
    PASS([dt("20240615") compare:dt("20240615T000000") withTime:YES] == NSOrderedSame,
	 "a date is equal to the local midnight of its day");
    PASS([dt("20240615") compare:dt("20240615T010000") withTime:YES] == NSOrderedAscending,
	 "a date is before 1h00 local time on its day");
    PASS([dt("20240615T010000") compare:dt("20240615") withTime:YES] == NSOrderedDescending,
	 "1h00 local time is after the date of its day");
    PASS([dt("20240614T230000") compare:dt("20240615") withTime:YES] == NSOrderedAscending,
	 "23h00 local time the day before is before a date");
  }

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
