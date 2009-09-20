#import "MemoryStoreTest.h"
#import "../MemoryStore.h"
#import "../Event.h"
#import "../Date.h"

@implementation MemoryStoreTest
- (void)setUp
{
  testStore = [[MemoryStore alloc] initWithName:@"testStore"];

  [self assertTrue:(testStore != nil) message:@"MemoryStore created."];
  [self assertTrue:([[testStore events] count] == 0 && [[testStore tasks] count] == 0) message:@"MemoryStore is empty on creation."];
}

- (void)tearDown
{
  [testStore release];
}

- (void)testStoreRetainCount
{
  Event *ev = [[Event alloc] initWithStartDate:[Date now] duration:60 title:@"Title"];

  [self assertInt:[ev retainCount] equals:1 message:@""];
  [testStore add:ev];
  [self assertInt:[ev retainCount] equals:2 message:@""];
  [testStore add:ev];
  [self assertInt:[ev retainCount] equals:2 message:@""];
  [testStore remove:ev];
  [self assertInt:[ev retainCount] equals:1 message:@""];
  [ev release];
}

- (void)testStoreElementCount
{
  MemoryStore *ms = [[MemoryStore alloc] initWithName:@"elementCount"];
  Event *ev = [[Event alloc] initWithStartDate:[Date now] duration:60 title:@"Title"];

  [ms add:ev];
  [self assertInt:[[ms events] count] equals:1 message:@"We added an event to the store."];
  [ms add:ev];
  [self assertInt:[[ms events] count] equals:1 message:@"If adding the same event twice, it appears only once."];
  [ms remove:ev];
  [self assertInt:[[ms events] count] equals:0 message:@"After removing this event the store is empty again."];
  [ev release];
  [ms release];
}
@end
