/* emacs buffer mode hint -*- objc -*- */

#import "Date.h"
#import "Element.h"
#import "AgendaStore.h"

extern NSString * const SADataChangedInStoreManager;

@interface StoreManager : NSObject
{
  NSMutableDictionary *_stores;
  NSMutableDictionary *_cache;
  id _defaultStore;
}

+ (NSArray *)backends;
+ (Class)backendForName:(NSString *)name;
+ (StoreManager *)globalManager;

- (void)addStoreNamed:(NSString *)name;
- (void)removeStoreNamed:(NSString *)name;
- (id <AgendaStore>)storeForName:(NSString *)name;
- (void)setDefaultStore:(NSString *)name;
- (id <AgendaStore>)defaultStore;
- (NSEnumerator *)storeEnumerator;
/* FIXME : add enabledStoreEnumerator ? */
- (void)synchronise;
- (void)refresh;
- (id <AgendaStore>)storeContainingElement:(Element *)elt;
- (NSArray *)allEvents;
- (NSArray *)allTasks;
- (NSSet *)scheduledAppointmentsForDay:(Date *)date;
@end
