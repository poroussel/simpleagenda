/* emacs buffer mode hint -*- objc -*- */

#import "Element.h"

@interface StoreManager : NSObject
{
  NSMutableDictionary *_stores;
  id _defaultStore;
  id _delegate;
}

+ (NSArray *)backends;
+ (Class)backendForName:(NSString *)name;

- (void)addStoreNamed:(NSString *)name;
- (void)removeStoreNamed:(NSString *)name;
- (id <AgendaStore>)storeForName:(NSString *)name;
- (void)setDefaultStore:(NSString *)name;
- (id <AgendaStore>)defaultStore;
- (NSEnumerator *)storeEnumerator;

- (void)synchronise;
- (void)setDelegate:(id)delegate;
- (id)delegate;
- (void)dataChanged:(NSNotification *)not;
- (id <AgendaStore>)storeContainingElement:(Element *)elt;
- (NSArray *)allEvents;
- (NSArray *)allTasks;
@end

@interface NSObject(StoreManagerDelegate)
- (void)dataChangedInStoreManager:(StoreManager *)sm;
@end
