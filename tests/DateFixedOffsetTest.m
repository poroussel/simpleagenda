/* -*- objc -*-
 *
 * Date in a fixed offset local timezone (GMT+0300), which GNUstep uses
 * for a 'Local Time Zone' default like GMT+0300. libical only knows it as
 * Etc/GMT-3. Date reads the timezone once, so this needs its own test
 * process.
 */

#import "ObjectTesting.h"
#import "Date.h"

static Date *dt(const char *string)
{
  return AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string(string)]);
}

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);
  icaltimezone *local;
  Date *d, *decoded;

  /* Before Date reads it */
  [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:3 * 3600]];

  START_SET("Date in a GMT+0300 timezone")
    PASS_EQUAL([[[NSCalendarDate calendarDate] timeZone] name], @"GMT+0300",
	       "GNUstep names the local timezone GMT+0300");
    local = (icaltimezone *)[[Date now] localICalTime].zone;
    PASS(local != NULL && strstr(icaltimezone_get_tzid(local), "Etc/GMT-3") != NULL,
	 "dates use libical's Etc/GMT-3 timezone");

    d = dt("20240615T120000Z");
    PASS([d hourOfDay] == 15, "an UTC time is converted to local time");
    PASS([d UTCICalTime].hour == 12, "-UTCICalTime converts back to UTC");
    d = dt("20240615T100000");
    PASS([d hourOfDay] == 10 && [d UTCICalTime].hour == 7,
	 "a floating time is read as local time");

    decoded = [NSKeyedUnarchiver unarchiveObjectWithData:
				   [NSKeyedArchiver archivedDataWithRootObject:d]];
    PASS([decoded isEqual:d] && [decoded UTCICalTime].hour == 7,
	 "NSCoding keeps a datetime");
  END_SET("Date in a GMT+0300 timezone")

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
