/* -*- objc -*- */

#import "ObjectTesting.h"
#import "Task.h"
#import "Date.h"

@implementation Task(Testing)
- (BOOL)isEqualForTestcase:(id)other
{
  if (other == nil || [other isKindOfClass:[Task class]] == NO)
    return NO;
  if ([[self summary] isEqualToString:[other summary]] == NO)
    return NO;
  if ([self state] != [other state])
    return NO;
  if (([self dueDate] == nil) != ([other dueDate] == nil))
    return NO;
  if ([self dueDate] &&
      [[self dueDate] compare:[other dueDate] withTime:NO] != NSOrderedSame)
    return NO;
  return YES;
}
@end

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  test_alloc(@"Task");

  Task *task = [[Task alloc] initWithSummary:@"Test Task"];

  PASS(task != nil, "-init works");
  PASS([task state] == TK_NONE, "default state is TK_NONE");
  PASS([task dueDate] == nil, "dueDate is nil by default");

  /* test_NSObject requires -description != nil; Task returns [self summary],
   * so the task must have a non-nil summary. */
  test_NSObject(@"Task", [NSArray arrayWithObject:task]);

  /* stateNamesArray */
  NSArray *names = [Task stateNamesArray];
  PASS(names != nil, "+stateNamesArray works");
  PASS([names count] == 5, "+stateNamesArray returns 5 entries");

  /* stateAsString */
  PASS([task stateAsString] != nil, "-stateAsString works for TK_NONE");

  /* setState: / state cycling through all values */
  [task setState:TK_INPROCESS];
  PASS([task state] == TK_INPROCESS, "-setState:TK_INPROCESS works");
  [task setState:TK_COMPLETED];
  PASS([task state] == TK_COMPLETED, "-setState:TK_COMPLETED works");
  [task setState:TK_CANCELED];
  PASS([task state] == TK_CANCELED, "-setState:TK_CANCELED works");
  [task setState:TK_NEEDSACTION];
  PASS([task state] == TK_NEEDSACTION, "-setState:TK_NEEDSACTION works");
  [task setState:TK_NONE];
  PASS([task state] == TK_NONE, "-setState:TK_NONE works");

  /* dueDate */
  Date *due = [Date today];
  [due setYear:2024];
  [due setMonth:12];
  [due setDay:31];
  [task setDueDate:due];
  PASS([task dueDate] != nil, "-setDueDate: works");
  PASS([[task dueDate] compare:due withTime:NO] == NSOrderedSame,
       "-dueDate returns the set date");

  [task setDueDate:nil];
  PASS([task dueDate] == nil, "-setDueDate:nil clears dueDate");

  /* NSCoding — without dueDate */
  Task *task2 = [[Task alloc] initWithSummary:@"NSCodingTest"];
  [task2 setState:TK_INPROCESS];
  test_keyed_NSCoding([NSArray arrayWithObject:task2]);

  /* NSCoding — with dueDate */
  Task *task3 = [[Task alloc] initWithSummary:@"NSCodingWithDate"];
  [task3 setState:TK_COMPLETED];
  [task3 setDueDate:due];
  test_keyed_NSCoding([NSArray arrayWithObject:task3]);

  [task release];
  [task2 release];
  [task3 release];
  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
