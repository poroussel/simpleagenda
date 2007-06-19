#import <Foundation/Foundation.h>
#import "AgendaStore.h"
#import "StoreManager.h"
#import "Event.h"
#import "AppointmentCache.h"

@implementation AppointmentCache

- (id)initwithStoreManager:(StoreManager *)sm 
		      from:(Date *)start 
			to:(Date *)end
{
  self = [super init];
  if (self) {
    _sm = sm;
    _start = [start copy];
    _end = [end copy];
    _cache = [[NSMutableSet alloc] initWithCapacity:16];
    [self refresh];
  }
  return self;
}

- (void)dealloc
{
  [_cache release];
  [_start release];
  [_end release];
  [super dealloc];
}

- (void)setFrom:(Date *)start to:(Date *)end
{
  [_start release];
  [_end release];
  _start = [start copy];
  _end = [end copy];
}

- (void)setTitle:(NSString *)title
{
  _title = title;
}

- (NSString *)title
{
  return _title;
}

- (void)refresh
{
  NSArray *array;
  NSEnumerator *enumerator;
  id <AgendaStore> store;

  [_cache removeAllObjects];
  enumerator = [_sm objectEnumerator];
  while ((store = [enumerator nextObject])) {
    if ([store displayed]) {
      array = [store scheduledAppointmentsFor:_start];
      [_cache addObjectsFromArray:array];
    }
  }  
}

- (NSEnumerator *)enumerator
{
  [self refresh];
  return [_cache objectEnumerator];
}

- (NSArray *)array
{
  [self refresh];
  return [NSArray arrayWithArray:[_cache allObjects]];
}

- (unsigned int)count
{
  [self refresh];
  return [_cache count];
}

@end
