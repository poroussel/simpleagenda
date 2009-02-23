/* emacs buffer mode hint -*- objc -*- */

#import "Date.h"
#import "Element.h"
#import "AgendaStore.h"

@protocol AgendaDataSource
- (NSSet *)scheduledAppointmentsForDay:(Date *)date;
- (Date *)selectedDate;
@end

#define SADataChanged @"DataDidChanged"

@interface StoreManager : NSObject
{
  NSMutableDictionary *_stores;
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
- (void)synchronise;
- (void)refresh;
- (id <AgendaStore>)storeContainingElement:(Element *)elt;
- (NSArray *)allEvents;
- (NSArray *)allTasks;
@end
