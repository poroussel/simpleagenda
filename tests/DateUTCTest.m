/* -*- objc -*-
 *
 * Date in a GMT+0000 local timezone, what GNUstep uses for TZ=UTC or
 * TZ=GMT and when it can't find the system timezone. Date reads the
 * timezone once, so this needs its own test process.
 */

#import "ObjectTesting.h"
#import "Date+ICal.h"

static Date *dt(const char *string)
{
  return AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string(string)]);
}

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);
  Date *d, *decoded;

  /* Before Date reads it */
  [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

  START_SET("Date in a GMT+0000 timezone")
    PASS_EQUAL([[[NSCalendarDate calendarDate] timeZone] name], @"GMT+0000",
	       "GNUstep names the local timezone GMT+0000");
    PASS([[Date now] localICalTime].zone == icaltimezone_get_utc_timezone(),
	 "dates use libical's UTC timezone");

    d = dt("20240615T120000Z");
    PASS([d hourOfDay] == 12, "an UTC time keeps its hour");
    PASS_EQUAL([d description], @"20240615T120000", "-description is the local wall time");
    PASS(icaltime_compare([d UTCICalTime], icaltime_from_string("20240615T120000Z")) == 0
	 && [d UTCICalTime].hour == 12,
	 "-UTCICalTime returns the same time");
    d = dt("20240615T100000");
    PASS([d localICalTime].zone == icaltimezone_get_utc_timezone()
	 && [d UTCICalTime].hour == 10,
	 "a floating time is read as local time");

    decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
				   [NSKeyedArchiver archivedDataWithRootObject:d]];
    PASS([decoded isEqual:d] && [decoded localICalTime].zone == icaltimezone_get_utc_timezone(),
	 "NSCoding keeps an UTC datetime");
    decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
				   [NSKeyedArchiver archivedDataWithRootObject:dt("20240615")]];
    PASS([decoded isDate] && [[decoded description] isEqualToString:@"20240615"],
	 "NSCoding keeps a date");
  END_SET("Date in a GMT+0000 timezone")

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
