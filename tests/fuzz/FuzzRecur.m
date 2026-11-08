/* -*- objc -*-
 *
 * libFuzzer harness for recurrent events : RecurrenceRule, its
 * enumerators and Event's recurrence handling (-intersectionWithDay:,
 * -isScheduledForDay:, -occurrenceEnumerator), with invariant checks.
 *
 * Input format : text, up to three lines
 *
 *   line 1 : DTSTART, parameters and value (";TZID=Europe/Paris:20240315T100000",
 *            ":20240315" ...). A leading ':' is added if missing.
 *   line 2 : RRULE value ("FREQ=WEEKLY;COUNT=10;BYDAY=MO,WE")
 *   line 3 : DURATION value ("PT1H"), optional (without it, an event
 *            starting on a date is an all day one, and an event starting
 *            at a time has no duration)
 *
 * They are wrapped in a VCALENDAR/VEVENT and parsed by iCalTree, like a
 * calendar file. Any crash, sanitizer report or uncaught ObjC exception is
 * a finding, and so are the invariants checked in checkEvent() :
 *
 *  - occurrences are strictly increasing (only increasing for sub-daily
 *    rules on all day events) and never before DTSTART
 *  - there are at most COUNT occurrences, none after UNTIL
 *  - the event is scheduled on the day of each of its first occurrences
 *  - libical finds no occurrence for a rule detected as never matching
 *    (-[RecurrenceRule neverMatches])
 *  - an archived event (LocalStore) and an event exported to iCalendar and
 *    parsed again have the same rule and the same occurrences
 *
 * Environment :
 *   FUZZ_TZ=<zone>             local timezone (default Europe/Paris)
 *   FUZZ_RECUR_INVARIANTS=0    only look for crashes
 *   FUZZ_RECUR_KNOWN=1         also check the known problems of sub-daily
 *                              rules on all day events (see checkEvent())
 *
 * Date limitations documented in Date.h (dates before 1902) are avoided
 * by only checking invariants for occurrences between 1902 and 2200.
 */

#import <Foundation/Foundation.h>
#import <string.h>
#import "iCalTree.h"
#import "Event.h"
#import "Date+ICal.h"
#import "RecurrenceRule+ICal.h"

/* Occurrences enumerated per event, and checked with -isScheduledForDay: */
#define MAX_OCCURRENCES 300
#define MAX_SCHEDULED 10

static BOOL checkInvariants = YES;
static BOOL checkKnown = NO;

static void failed(NSString *what, Event *ev, NSString *more)
{
  NSString *rule = @"(none)";

  if ([ev rrule])
    rule = [[ev rrule] stringValue] ? [[ev rrule] stringValue] : @"(not printable)";
  NSLog(@"Invariant failed : %@\n  start %@ allDay %d duration %d\n  rrule %@\n  %@",
        what, [ev startDate], [ev allDay], [ev duration], rule, more ? more : @"");
  abort();
}

static NSString *ruleString(RecurrenceRule *rule)
{
  if (rule == nil)
    return nil;
  return [rule stringValue] ? [rule stringValue] : @"";
}

static BOOL checkable(Date *d)
{
  return [d year] >= 1902 && [d year] <= 2200;
}

static NSArray *occurrences(Event *ev)
{
  NSMutableArray *all = [NSMutableArray array];
  NSEnumerator *e = [ev occurrenceEnumerator];
  Date *d;

  while ([all count] < MAX_OCCURRENCES && (d = [e nextObject]))
    [all addObject:d];
  return all;
}

static void sameOccurrences(Event *ev, NSArray *a, NSArray *b, NSString *what)
{
  NSUInteger i;

  if ([a count] != [b count])
    failed([NSString stringWithFormat:@"%@ : %lu occurrences instead of %lu", what,
                     (unsigned long)[b count], (unsigned long)[a count]], ev, nil);
  for (i = 0; i < [a count]; i++) {
    Date *da = [a objectAtIndex:i];
    Date *db = [b objectAtIndex:i];
    if (checkable(da) && [da compare:db withTime:YES] != NSOrderedSame)
      failed([NSString stringWithFormat:@"%@ : occurrence %lu differs", what, (unsigned long)i],
             ev, [NSString stringWithFormat:@"%@ != %@", da, db]);
  }
}

static void checkEvent(Event *ev)
{
  RecurrenceRule *rule = [ev rrule];
  struct icalrecurrencetype r = [rule iCalRRule];
  NSArray *all = occurrences(ev);
  Date *start = [ev startDate];
  /*
   * -until normalizes an out of range UNTIL (20240400 is March 31st) but
   * libical uses it as is : only check UNTIL values that are valid
   */
  Date *until = icaltime_compare(icaltime_normalize(r.until), r.until) ? nil : [rule until];
  Date *previous = nil;
  NSUInteger i;
  /*
   * Known : sub-daily rules on all day events.
   * - libical repeats the same date (24 times for FREQ=HOURLY), so only
   *   check the order
   * - -[Event setAllDay:] keeps the timezone of the start date, which
   *   isn't archived or exported with a DATE value : libical adds the
   *   hours with or without DST and the occurrences can change day
   */
  BOOL subDaily = [start isDate] && r.freq < ICAL_DAILY_RECURRENCE;
  NSComparisonResult worst = subDaily ? NSOrderedSame : NSOrderedAscending;

  if (!checkable(start))
    return;

  /* A rule detected as never matching mustn't have any occurrence */
  if ([rule neverMatches]) {
    icalrecur_iterator *it = icalrecur_iterator_new(r, [start localICalTime]);

    if (it && !icaltime_is_null_time(icalrecur_iterator_next(it)))
      failed(@"a rule detected as never matching has occurrences", ev, nil);
    if (it)
      icalrecur_iterator_free(it);
  }

  for (i = 0; i < [all count]; i++) {
    Date *d = [all objectAtIndex:i];

    if (!checkable(d))
      break;
    if ([d compare:start withTime:YES] == NSOrderedAscending)
      failed(@"occurrence before DTSTART", ev, [d description]);
    if (previous && [previous compare:d withTime:YES] > worst)
      failed(@"occurrences not strictly increasing", ev,
             [NSString stringWithFormat:@"%@ then %@", previous, d]);
    if (until && checkable(until) && [d compare:until withTime:![until isDate]] == NSOrderedDescending)
      failed(@"occurrence after UNTIL", ev, [NSString stringWithFormat:@"%@ > %@", d, until]);
    previous = d;
  }
  if (r.count > 0 && [all count] > (NSUInteger)r.count)
    failed(@"more occurrences than COUNT", ev, nil);

  /* The event must be visible on the day of its occurrences */
  if ([ev allDay] || [ev duration] >= 0) {
    for (i = 0; i < [all count] && i < MAX_SCHEDULED; i++) {
      Date *d = [all objectAtIndex:i];
      Date *day = [Date dayWithDate:d];

      if (!checkable(d))
        break;
      if (![ev isScheduledForDay:day])
        failed(@"not scheduled on the day of an occurrence", ev, [day description]);
    }
  }

  if (subDaily && !checkKnown)
    return;

  /* LocalStore path */
  {
    Event *copy = [NSKeyedUnarchiver unarchiveObjectWithData:
                                       [NSKeyedArchiver archivedDataWithRootObject:ev]];
    if (![ruleString([copy rrule]) isEqualToString:ruleString(rule)])
      failed(@"archived rule changed", ev, ruleString([copy rrule]));
    sameOccurrences(ev, all, occurrences(copy), @"archived event");
  }

  /* iCalendar export path */
  {
    ICalComponent *ic = [ev asICalComponent];
    Event *parsed;

    if (ic) {
      parsed = AUTORELEASE([[Event alloc] initWithICalComponent:ic]);
      if (parsed == nil)
        failed(@"exported event can't be read back", ev, nil);
      sameOccurrences(ev, all, occurrences(parsed), @"exported event");
    }
  }
}

static NSString *line(NSArray *lines, NSUInteger i)
{
  NSString *l;

  if (i >= [lines count])
    return @"";
  l = [lines objectAtIndex:i];
  return [l stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r"]];
}

int LLVMFuzzerInitialize(int *argc, char ***argv)
{
  const char *inv = getenv("FUZZ_RECUR_INVARIANTS");

  setenv("TZ", getenv("FUZZ_TZ") ? getenv("FUZZ_TZ") : "Europe/Paris", 1);
  checkInvariants = !(inv && !strcmp(inv, "0"));
  checkKnown = getenv("FUZZ_RECUR_KNOWN") && !strcmp(getenv("FUZZ_RECUR_KNOWN"), "1");
  [Date class];
  return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSString *input, *dtstart, *rrule, *duration;
  NSArray *lines;
  NSMutableString *ics;
  iCalTree *tree;
  NSEnumerator *e;
  Element *elt;

  input = AUTORELEASE([[NSString alloc] initWithBytes:data length:size encoding:NSUTF8StringEncoding]);
  if (input == nil) {
    [pool release];
    return 0;
  }
  lines = [input componentsSeparatedByString:@"\n"];
  dtstart = line(lines, 0);
  rrule = line(lines, 1);
  duration = line(lines, 2);
  if (![dtstart hasPrefix:@";"] && ![dtstart hasPrefix:@":"])
    dtstart = [@":" stringByAppendingString:dtstart];

  ics = [NSMutableString stringWithString:@"BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"
                         @"PRODID:-//SimpleAgenda//fuzz//EN\r\nBEGIN:VEVENT\r\n"
                         @"UID:recur@simpleagenda\r\nDTSTAMP:20240101T000000Z\r\n"];
  [ics appendFormat:@"DTSTART%@\r\nRRULE:%@\r\n", dtstart, rrule];
  if ([duration length])
    [ics appendFormat:@"DURATION:%@\r\n", duration];
  [ics appendString:@"SUMMARY:recur\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"];

  tree = AUTORELEASE([iCalTree new]);
  @try {
    if ([tree parseData:[ics dataUsingEncoding:NSUTF8StringEncoding]]) {
      e = [[tree components] objectEnumerator];
      while ((elt = [e nextObject])) {
        Event *ev;

        if (![elt isKindOfClass:[Event class]] || ![(Event *)elt rrule])
          continue;
        ev = (Event *)elt;
        if (checkInvariants)
          checkEvent(ev);
        else {
          occurrences(ev);
          [ev isScheduledForDay:[Date dayWithDate:[ev startDate]]];
          [NSKeyedUnarchiver unarchiveObjectWithData:
                               [NSKeyedArchiver archivedDataWithRootObject:ev]];
        }
      }
    }
  } @catch (NSException *ex) {
    NSLog(@"Uncaught exception %@ : %@\n%@", [ex name], [ex reason],
          [[ex callStackSymbols] componentsJoinedByString:@"\n"]);
    abort();
  }
  [pool release];
  return 0;
}
