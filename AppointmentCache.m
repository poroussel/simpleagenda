#import <Foundation/Foundation.h>
#import "AgendaStore.h"
#import "StoreManager.h"
#import "Event.h"
#import "AppointmentCache.h"

@implementation AppointmentCache

- (void)populateFrom:(id <AgendaStore>)source
{
  NSEnumerator *enumerator;
  NSEnumerator *eventEnumerator;
  id <AgendaStore> store;
  Event *event;

  if (source == nil) {
    [_cache removeAllObjects];
    enumerator = [_sm objectEnumerator];
    while ((store = [enumerator nextObject])) {
      eventEnumerator = [store enumerator];
      while ((event = [eventEnumerator nextObject])) {
	if ([event isScheduledBetweenDay:_start andDay:_end])
	  [_cache addObject:event];
      }
    } 
  } else {
    enumerator = [_cache objectEnumerator];
    while ((event = [enumerator nextObject])) {
      if ([source isEqual:[event store]])
	[_cache removeObject:event];
    }
    eventEnumerator = [source enumerator];
    while ((event = [eventEnumerator nextObject])) {
      if ([event isScheduledBetweenDay:_start andDay:_end])
	[_cache addObject:event];
    }
  }
}

- (id)initwithStoreManager:(StoreManager *)sm 
		      date:(Date *)date
		  duration:(int)days
{
  self = [super init];
  if (self) {
    _sm = sm;
    _duration = days;
    _start = [date copy];
    _end = [date copy];
    [_end changeDayBy:days - 1];
    _cache = [[NSMutableSet alloc] initWithCapacity:16];
    [[NSNotificationCenter defaultCenter] addObserver:self 
					  selector:@selector(dataChanged:) 
					  name:SADataChangedInStore 
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

- (void)setDate:(Date *)date;
{
  [_start release];
  [_end release];
  _start = [date copy];
  _end = [date copy];
  [_end changeDayBy:_duration - 1];
  [self populateFrom:nil];
}

- (void)setDuration:(int)days;
{
  _duration = days;
  [_end release];
  _end = [_start copy];
  [_end changeDayBy:days - 1];
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
