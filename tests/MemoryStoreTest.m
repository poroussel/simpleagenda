#import "MemoryStoreTest.h"
#import "../MemoryStore.h"
#import "../Event.h"
#import "../Date.h"

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

@implementation MemoryStoreTest
- (void)setUp
{
  testStore = [[SimpleStore alloc] initWithName:@"testStore"];
}

- (void)tearDown
{
  [testStore release];
}

- (void)testStoreCreation
{
  MemoryStore *ms = [[SimpleStore alloc] initWithName:@"elementCount"];

  [self assertTrue:(ms != nil) message:@"MemoryStore created."];
  [self assertTrue:[ms events] && [ms tasks] message:@"Events and tasks dictionaries exist."];
  [self assertTrue:([[ms events] count] == 0 && [[ms tasks] count] == 0) message:@"MemoryStore is empty on creation."];
  [ms release];
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
  MemoryStore *ms = [[SimpleStore alloc] initWithName:@"elementCount"];
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
