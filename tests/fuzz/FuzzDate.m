/* -*- objc -*-
 *
 * libFuzzer harness for Date : builds a few dates from fuzzed iCalendar
 * time strings (the way iCalTree and LocalStore create them), then runs
 * a fuzzed sequence of the operations the UI performs on them.
 *
 * Input layout (consumed byte by byte, missing bytes read as 0) :
 *   1 byte          number of dates (1 to 4)
 *   per date        1 byte kind, then kind specific data :
 *                     0 : string        icaltime_from_string + initWithICalTime:
 *                     1 : string string initWithCoder: (icalTime, timezone)
 *                     2 : 4 bytes       dateWithCalendarDate:withTime:
 *                   a string is 1 length byte followed by that many bytes
 *   rest            operations : 1 byte opcode, 1 byte target(s), 2 bytes argument
 *
 * Besides crashes and sanitizer reports, a few invariants are checked
 * (copy/equality/hash, comparison symmetry, archiving round trip, day
 * arithmetic reversibility). Set FUZZ_DATE_INVARIANTS=0 to disable them.
 *
 * Known issue : libical's icaltime_as_timet() returns -1 for every date
 * before 1902, so Date's isEqual:, hash, timeIntervalSinceDate: and
 * weekOfYear are wrong for them (all such dates are equal, day enumeration
 * never ends). And timeIntervalSinceDate: goes through
 * icaldurationtype_as_int(), which overflows an int when the dates are
 * more than 68 years apart. Finally, libical accepts out of range fields
 * (DTSTART;VALUE=DATE:20262311 or 20260230T120000) and initWithICalTime:
 * doesn't normalize dates and floating times, so these dates compare
 * inconsistently. Also, initWithCoder: keeps the archived timezone instead
 * of converting to the local one like initWithICalTime: does, so after a
 * timezone change the same instant can be isEqual: NO (zone unaware) and
 * compare:withTime:YES NSOrderedSame (zone aware). Invariants are not
 * checked for these cases unless FUZZ_DATE_KNOWN=1 is set.
 */

#import <Foundation/Foundation.h>
#import "Date+ICal.h"

#define MAX_OPS 64
#define MAX_ENUM_DAYS 1000

typedef struct {
  const uint8_t *data;
  size_t size;
  size_t pos;
} Reader;

static BOOL checkInvariants = YES;
static BOOL checkKnown = NO;

/* Dates for which invariants are expected to hold */
static BOOL checkable(Date *d)
{
  struct icaltimetype t, n;

  if (!checkInvariants || [d year] > 9999)
    return NO;
  if (checkKnown)
    return YES;
  t = [d localICalTime];
  n = icaltime_normalize(t);
  return t.year >= 1902 && t.month == n.month && t.day == n.day &&
    t.hour == n.hour && t.minute == n.minute && t.second == n.second;
}

static uint8_t u8(Reader *r)
{
  return r->pos < r->size ? r->data[r->pos++] : 0;
}

static int16_t s16(Reader *r)
{
  uint16_t v = u8(r);
  return (int16_t)(v | (u8(r) << 8));
}

static NSString *string(Reader *r)
{
  size_t len = u8(r);
  NSString *s;

  if (len > r->size - r->pos)
    len = r->size - r->pos;
  s = [[NSString alloc] initWithBytes:r->data + r->pos length:len encoding:NSUTF8StringEncoding];
  if (s == nil)
    s = [[NSString alloc] initWithBytes:r->data + r->pos length:len encoding:NSISOLatin1StringEncoding];
  r->pos += len;
  return [s autorelease];
}

/* Plays the part of the NSKeyedUnarchiver used by LocalStore */
@interface FuzzCoder : NSCoder
{
  NSDictionary *_values;
}
- (id)initWithValues:(NSDictionary *)values;
@end
@implementation FuzzCoder
- (id)initWithValues:(NSDictionary *)values
{
  if ((self = [super init]))
    _values = [values retain];
  return self;
}
- (void)dealloc
{
  [_values release];
  [super dealloc];
}
- (BOOL)allowsKeyedCoding
{
  return YES;
}
- (id)decodeObjectForKey:(NSString *)key
{
  return [_values objectForKey:key];
}
- (BOOL)containsValueForKey:(NSString *)key
{
  return [_values objectForKey:key] != nil;
}
@end

static NSString *details(Date *d)
{
  struct icaltimetype t;
  const char *tzid;

  if (d == nil)
    return @"nil";
  t = [d localICalTime];
  tzid = t.zone ? icaltime_get_tzid(t) : NULL;
  return [NSString stringWithFormat:@"%@ (%s %02d:%02d:%02d, %s)", d, t.is_date ? "date" : "datetime", t.hour, t.minute, t.second, tzid ? tzid : "floating"];
}

static void failed(NSString *what, Date *a, Date *b)
{
  NSLog(@"Invariant failed : %@\n  %@\n  %@", what, details(a), details(b));
  abort();
}

static Date *makeDate(Reader *r)
{
  Date *d = nil;

  switch (u8(r) % 3) {
  case 0: {
    NSString *s = string(r);
    struct icaltimetype t = icaltime_from_string([s UTF8String]);
    d = [[[Date alloc] initWithICalTime:t] autorelease];
    break;
  }
  case 1: {
    NSString *time = string(r);
    NSString *tz = string(r);
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithObject:time forKey:@"icalTime"];
    FuzzCoder *coder;

    if ([tz length])
      [values setObject:tz forKey:@"timezone"];
    coder = [[[FuzzCoder alloc] initWithValues:values] autorelease];
    /* NSCoding is implemented in a category not declared in Date.h */
    d = [[(id)[Date alloc] initWithCoder:coder] autorelease];
    break;
  }
  case 2: {
    uint32_t v = u8(r) | (u8(r) << 8) | (u8(r) << 16) | ((uint32_t)u8(r) << 24);
    NSCalendarDate *cd = [NSCalendarDate dateWithTimeIntervalSince1970:(NSTimeInterval)(v >> 1)];
    d = [Date dateWithCalendarDate:cd withTime:v & 1];
    break;
  }
  }
  return d;
}

static void readers(Date *d)
{
  [d description];
  [d year];
  [d monthOfYear];
  [d dayOfMonth];
  [d hourOfDay];
  [d minuteOfHour];
  [d secondOfMinute];
  [d minuteOfDay];
  [d weekday];
  [d weekOfYear];
  [d numberOfDaysInMonth];
  [d isDate];
  [d timeIntervalSince1970];
  [d timeIntervalSinceNow];
  [d calendarDate];
  [d UTCICalTime];
  [d localICalTime];
}

static void invariants(Date *a, Date *b)
{
  Date *c = [[a copy] autorelease];
  Date *u;
  NSComparisonResult ab, ba;

  if (!checkable(a) || !checkable(b))
    return;

  if (![c isEqual:a] || [c hash] != [a hash])
    failed(@"copy is equal with the same hash", a, c);
  if ([a isEqual:b] && [a hash] != [b hash])
    failed(@"equal dates have the same hash", a, b);
  if ([a isEqual:nil])
    failed(@"a date is not equal to nil", a, nil);

  ab = [a compare:b withTime:YES];
  ba = [b compare:a withTime:YES];
  if (ab != -ba)
    failed(@"compare:withTime:YES is antisymmetric", a, b);
  ab = [a compare:b withTime:NO];
  ba = [b compare:a withTime:NO];
  if (ab != -ba)
    failed(@"compare:withTime:NO is antisymmetric", a, b);
  if ([a compare:c withTime:YES] != NSOrderedSame || [a compare:c withTime:NO] != NSOrderedSame)
    failed(@"a date is the same as its copy", a, c);
  /* The remaining checks compare two dates : skip mixed timezones */
  if (!checkKnown && [a localICalTime].zone != [b localICalTime].zone)
    return;
  if ([a isEqual:b] != ([a compare:b withTime:YES] == NSOrderedSame))
    failed(@"isEqual: agrees with compare:withTime:YES", a, b);
  if ((checkKnown || abs([a year] - [b year]) < 60) &&
      [a compare:b withTime:YES] != NSOrderedSame &&
      ([a timeIntervalSinceDate:b] > 0) != ([a compare:b withTime:YES] > 0))
    failed(@"timeIntervalSinceDate: agrees with compare:withTime:YES", a, b);

  u = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:a]];
  if (![u isEqual:a])
    failed(@"archiving round trip", a, u);
}

static void operate(Reader *r, Date **dates, int ndates)
{
  int ops;

  for (ops = 0; ops < MAX_OPS && r->pos < r->size; ops++) {
    uint8_t op = u8(r);
    uint8_t target = u8(r);
    int16_t arg = s16(r);
    Date *d = dates[target % ndates];
    Date *o = dates[(target >> 4) % ndates];

    switch (op % 20) {
    case 0: readers(d); break;
    case 1: [d setDay:arg]; break;
    case 2: [d setMonth:arg % 2400]; break;
    /* Years are kept within a few centuries : beyond 2100 or so, every
     * libical timezone conversion takes milliseconds and slows fuzzing
     * down. Far years still come from the fuzzed time strings. */
    case 3: [d setYear:1700 + arg % 500]; break;
    case 4: [d incrementDay]; break;
    case 5: [d changeYearBy:arg % 200]; break;
    case 6: [d changeDayBy:arg]; break;
    case 7:
      /* Like setMinute:, only meaningful for datetimes : on a date, libical
       * keeps the minutes unnormalized and isEqual:/compare: disagree */
      if (![d isDate]) [d changeMinuteBy:arg];
      break;
    case 8: if (![d isDate]) [d setMinute:arg]; break;
    case 9: if (![d isDate]) [d setSecondOfMinute:arg]; break;
    case 10: [d setIsDate:arg & 1]; break;
    case 11:
      /* What the calendar view does to go to the previous/next month */
      [d setMonth:[d monthOfYear] + (arg & 1 ? 1 : -1)];
      break;
    case 12:
      /* Week view : go to the first day of the week */
      [d changeDayBy:1 - [d weekday]];
      break;
    case 13:
      dates[target % ndates] = [Date dateWithTimeInterval:arg * 60 sinceDate:o];
      break;
    case 14:
      dates[target % ndates] = [Date dayWithDate:o];
      break;
    case 15: {
      NSTimeInterval span = [o timeIntervalSinceDate:d];
      if (span >= 0 && span < MAX_ENUM_DAYS * 86400.0) {
        NSEnumerator *e = [d enumeratorTo:o];
        int n = 0;
        while (n++ <= MAX_ENUM_DAYS + 2 && [e nextObject])
          ;
        if (checkable(d) && checkable(o) && n > MAX_ENUM_DAYS + 2)
          failed(@"day enumeration terminates", d, o);
      }
      break;
    }
    case 16:
      [d compare:o withTime:arg & 1];
      [d timeIntervalSinceDate:o];
      [d isEqual:o];
      break;
    case 17:
      if (checkable(d)) {
        Date *c = [[d copy] autorelease];
        [c changeDayBy:arg];
        [c changeDayBy:-arg];
        if (![c isEqual:d])
          failed(@"changeDayBy:n then changeDayBy:-n", d, c);
      }
      break;
    case 18:
      dates[target % ndates] = [[[Date alloc] initWithICalTime:[o UTCICalTime]] autorelease];
      break;
    case 19:
      if (checkInvariants)
        invariants(d, o);
      break;
    }
  }
}

int LLVMFuzzerInitialize(int *argc, char ***argv)
{
  const char *inv = getenv("FUZZ_DATE_INVARIANTS");

  /* A timezone with daylight saving time, unless the user chose one */
  setenv("TZ", getenv("FUZZ_TZ") ? getenv("FUZZ_TZ") : "Europe/Paris", 1);
  checkInvariants = !(inv && !strcmp(inv, "0"));
  checkKnown = getenv("FUZZ_DATE_KNOWN") && !strcmp(getenv("FUZZ_DATE_KNOWN"), "1");
  [Date class];
  return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  Reader r = { data, size, 0 };
  Date *dates[4];
  int ndates, i;

  @try {
    ndates = 1 + u8(&r) % 4;
    for (i = 0; i < ndates; i++)
      dates[i] = makeDate(&r);
    for (i = 0; i < ndates; i++)
      readers(dates[i]);
    operate(&r, dates, ndates);
    for (i = 0; i < ndates; i++) {
      readers(dates[i]);
      if (checkInvariants)
        invariants(dates[i], dates[(i + 1) % ndates]);
    }
  } @catch (NSException *ex) {
    NSLog(@"Uncaught exception %@ : %@\n%@", [ex name], [ex reason], [ex callStackSymbols]);
    abort();
  }
  [pool release];
  return 0;
}
