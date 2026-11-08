/* -*- objc -*-
 *
 * libFuzzer harness for iCalTree : parses arbitrary bytes as an iCalendar
 * document, builds Event/Task objects from it, then serializes everything
 * back. Any crash, sanitizer report or uncaught ObjC exception is a finding.
 */

#import <Foundation/Foundation.h>
#import "iCalTree.h"
#import "Element.h"
#import "Event.h"
#import "Task.h"
#import "Date.h"

static void exercise(Element *elt)
{
  [elt summary];
  [elt UID];
  [elt text];
  [elt categories];
  [elt alarms];
  [elt nextActivationDate];
  if ([elt isKindOfClass:[Event class]]) {
    Event *ev = (Event *)elt;
    [ev startDate];
    [ev duration];
    [ev rrule];
    [ev location];
    [ev details];
    [ev allDay];
    [ev sticky];
    /* Recurrence expansion, bounded so infinite rules don't look like hangs */
    {
      NSEnumerator *re = [ev occurrenceEnumerator];
      int n = 0;
      while (n++ < 200 && [re nextObject])
        ;
    }
    [ev isScheduledForDay:[Date today]];
  } else if ([elt isKindOfClass:[Task class]]) {
    [(Task *)elt dueDate];
    [(Task *)elt state];
  }
  /* Reverse path : Element -> iCalendar */
  [[elt asICalComponent] stringValue];
  /* NSCoding path, used by LocalStore */
  [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:elt]];
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  iCalTree *tree = [iCalTree new];
  NSEnumerator *e;
  Element *elt;
  NSSet *components;
  iCalTree *tree2;

  @try {
    if ([tree parseData:[NSData dataWithBytes:data length:size]]) {
      components = [tree components];
      e = [components objectEnumerator];
      while ((elt = [e nextObject]))
        exercise(elt);
      /* Round-trip : serialized output must be parseable again */
      tree2 = [[iCalTree new] autorelease];
      if ([tree2 parseData:[tree iCalTreeAsData]])
        [tree2 components];
      /* Mutation paths */
      e = [components objectEnumerator];
      while ((elt = [e nextObject])) {
        [tree update:elt];
        [tree remove:elt];
      }
    }
  } @catch (NSException *ex) {
    NSLog(@"Uncaught exception %@ : %@\n%@", [ex name], [ex reason],
          [[ex callStackSymbols] componentsJoinedByString:@"\n"]);
    abort();
  }
  [tree release];
  [pool release];
  return 0;
}
