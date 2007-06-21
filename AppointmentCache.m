#import <Foundation/Foundation.h>
#import "AgendaStore.h"
#import "StoreManager.h"
#import "Event.h"
#import "AppointmentCache.h"

@implementation AppointmentCache

- (void)populateFrom:(id <AgendaStore>)source
{
  NSArray *array;
  NSEnumerator *enumerator;
  id <AgendaStore> store;
  Event *event;

  if (source == nil) {
    [_cache removeAllObjects];
    enumerator = [_sm objectEnumerator];
    while ((store = [enumerator nextObject])) {
      array = [store scheduledAppointmentsFor:_start];
      [_cache addObjectsFromArray:array];
    } 
  } else {
    enumerator = [_cache objectEnumerator];
    while ((event = [enumerator nextObject])) {
      if ([source isEqual:[event store]])
	[_cache removeObject:event];
    }
    array = [source scheduledAppointmentsFor:_start];
    [_cache addObjectsFromArray:array];
  }
}

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
    [[NSNotificationCenter defaultCenter] addObserver:self 
					  selector:@selector(dataChanged:) 
					  name:SADataChangedInStore 
					  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self 
					  selector:@selector(parametersChanged:) 
					  name:SADefaultsChangedforStore 
					  object:nil];
    [self populateFrom:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
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
  [self populateFrom:nil];
}

- (void)setTitle:(NSString *)title
{
  _title = title;
}

- (NSString *)title
{
  return _title;
}

- (NSString *)details
{
  return [NSString stringWithFormat:@"%d item(s)", [self count]];;
}

- (void)dataChanged:(NSNotification *)not
{
  [self populateFrom:[not object]];
  if ([_delegate respondsToSelector:@selector(dataChangedInCache:)])
    [_delegate dataChangedInCache:self];
}

- (void)parametersChanged:(NSNotification *)not
{
  if ([_delegate respondsToSelector:@selector(dataChangedInCache:)])
    [_delegate dataChangedInCache:self];
}

- (NSEnumerator *)enumerator
{
  return [_cache objectEnumerator];
}

- (NSArray *)array
{
  return [NSArray arrayWithArray:[_cache allObjects]];
}

- (unsigned int)count
{
  return [_cache count];
}

- (void)setDelegate:(id)delegate
{
  _delegate = delegate;
}

- (id)delegate
{
  return _delegate;
}

@end
