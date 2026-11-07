/* emacs buffer mode hint -*- objc -*- */

#import "Date.h"
#import "Element.h"
#import "AgendaStore.h"

extern NSString * const SADataChangedInStoreManager;

@interface StoreManager : NSObject
{
  NSMutableDictionary *_stores;
  NSMutableDictionary *_dayEventsCache;
  NSMutableArray *_eventCache;
  id _defaultStore;
  NSOperationQueue *_opqueue;
}

+ (NSArray *)backends;
+ (Class)backendForName:(NSString *)name;
+ (StoreManager *)globalManager;

- (NSOperationQueue *)operationQueue;
- (void)addStoreNamed:(NSString *)name;
- (void)removeStoreNamed:(NSString *)name;
- (id <AgendaStore>)storeForName:(NSString *)name;
- (void)setDefaultStore:(NSString *)name;
- (id <AgendaStore>)defaultStore;
- (NSEnumerator *)storeEnumerator;
- (void)synchronise;
- (void)refresh;
- (id <AgendaStore>)storeContainingElement:(Element *)elt;
- (BOOL)moveElement:(Element *)elt toStore:(id <MemoryStore>)store;
- (NSArray *)allEvents;
- (NSArray *)allTasks;
- (NSSet *)scheduledAppointmentsForDay:(Date *)date;
- (NSSet *)visibleAppointmentsForDay:(Date *)date;
- (NSArray *)visibleTasks;
@end
