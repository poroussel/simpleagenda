/* -*- objc -*- */

#import "ObjectTesting.h"
#import "iCalTree.h"
#import "Event.h"
#import "Task.h"
#import "Date.h"

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  test_alloc(@"iCalTree");

  iCalTree *tree = [[iCalTree alloc] init];
  PASS(tree != nil, "-init works");

  NSSet *empty = [tree components];
  PASS(empty != nil, "-components returns non-nil on empty tree");
  PASS([empty count] == 0, "-components returns empty set on new tree");

  test_NSObject(@"iCalTree", [NSArray arrayWithObject:tree]);

  /* add: an event */
  Date *start = [Date today];
  [start setYear:2024];
  [start setMonth:3];
  [start setDay:15];
  [start setIsDate:NO];
  [start changeMinuteBy:600]; /* 10h00 */

  Event *ev = [[Event alloc] initWithStartDate:start duration:60
                                          title:@"Test Event"];
  BOOL added = [tree add:ev];
  PASS(added, "-add: event returns YES");
  PASS([[tree components] count] == 1,
       "-components count is 1 after adding an event");

  /* add: a task */
  Task *task = [[Task alloc] initWithSummary:@"Test Task"];
  BOOL taskAdded = [tree add:task];
  PASS(taskAdded, "-add: task returns YES");
  PASS([[tree components] count] == 2,
       "-components count is 2 after adding a task");

  /* iCalTreeAsString */
  NSString *icalStr = [tree iCalTreeAsString];
  PASS(icalStr != nil, "-iCalTreeAsString returns non-nil");
  PASS([icalStr length] > 0, "-iCalTreeAsString returns non-empty string");
  PASS([icalStr rangeOfString:@"BEGIN:VCALENDAR"].length > 0,
       "-iCalTreeAsString contains VCALENDAR wrapper");
  PASS([icalStr rangeOfString:@"BEGIN:VEVENT"].length > 0,
       "-iCalTreeAsString contains VEVENT component");
  PASS([icalStr rangeOfString:@"SUMMARY:Test Event"].length > 0,
       "-iCalTreeAsString contains event summary");
  PASS([icalStr rangeOfString:@"BEGIN:VTODO"].length > 0,
       "-iCalTreeAsString contains VTODO component");
  PASS([icalStr rangeOfString:@"SUMMARY:Test Task"].length > 0,
       "-iCalTreeAsString contains task summary");

  /* iCalTreeAsData */
  NSData *icalData = [tree iCalTreeAsData];
  PASS(icalData != nil, "-iCalTreeAsData returns non-nil");
  PASS([icalData length] > 0, "-iCalTreeAsData returns non-empty data");

  /* parseString: round-trip */
  iCalTree *tree2 = [[iCalTree alloc] init];
  BOOL parsed = [tree2 parseString:icalStr];
  PASS(parsed, "-parseString: returns YES for valid iCal string");
  PASS([[tree2 components] count] == 2,
       "-components returns 2 elements after parseString: round-trip");

  /* parseData: round-trip */
  iCalTree *tree3 = [[iCalTree alloc] init];
  BOOL parsedData = [tree3 parseData:icalData];
  PASS(parsedData, "-parseData: returns YES for valid iCal data");
  PASS([[tree3 components] count] == 2,
       "-components returns 2 elements after parseData: round-trip");

  /* parseString: with nil returns NO */
  iCalTree *tree4 = [[iCalTree alloc] init];
  BOOL nilParse = [tree4 parseString:nil];
  PASS(!nilParse, "-parseString:nil returns NO");

  /* remove: */
  BOOL removed = [tree remove:ev];
  PASS(removed, "-remove: returns YES for existing element");
  PASS([[tree components] count] == 1,
       "-components count is 1 after remove");

  BOOL notRemoved = [tree remove:ev];
  PASS(!notRemoved, "-remove: returns NO for element not in tree");

  /* update: */
  [task setSummary:@"Updated Task"];
  BOOL updated = [tree update:task];
  PASS(updated, "-update: returns YES for existing element");
  NSString *updatedStr = [tree iCalTreeAsString];
  PASS([updatedStr rangeOfString:@"SUMMARY:Updated Task"].length > 0,
       "-update: modifies the summary in the serialized output");

  [ev release];
  [task release];
  [tree release];
  [tree2 release];
  [tree3 release];
  [tree4 release];
  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
