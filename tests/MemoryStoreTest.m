/* -*- objc -*- */

#import "ObjectTesting.h"
#import "MemoryStore.h"
#import "Event.h"

@interface SimpleStore : MemoryStore
{
}
@end
@implementation SimpleStore
- (NSDictionary *)defaults
{
  return nil;
}
@end

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  MemoryStore *testStore;

  test_alloc(@"MemoryStore");

  testStore = [[SimpleStore alloc] initWithName:@"testStore"];

  test_NSObject(@"MemoryStore", [NSArray arrayWithObject:testStore]);

  MemoryStore *ms = [[SimpleStore alloc] initWithName:@"elementCount"];

  PASS(ms != nil, "MemoryStore created.");
  PASS([ms events] && [ms tasks], "Events and tasks dictionaries exist.");
  PASS([[ms events] count] == 0 && [[ms tasks] count] == 0,
       "MemoryStore is empty on creation.");

  Event *ev = [[Event alloc] initWithStartDate:[Date now] duration:60 title:@"Title"];

  PASS([ev retainCount] == 1, "");
  [testStore add:ev];
  PASS([ev retainCount] == 2, "");
  [testStore add:ev];
  PASS([ev retainCount] == 2, "");
  [testStore remove:ev];
  PASS([ev retainCount] == 1, "");

  [ms add:ev];
  PASS([[ms events] count] == 1, "We added an event to the store.");
  [ms add:ev];
  PASS([[ms events] count] == 1,
       "If adding the same event twice, it appears only once.");
  [ms remove:ev];
  PASS([[ms events] count] == 0,
       "After removing this event the store is empty again.");
  [ev release];
  [ms release];
  [testStore release];

  RELEASE(arp);

  exit(EXIT_SUCCESS);
}
