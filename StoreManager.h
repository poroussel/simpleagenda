/* emacs buffer mode hint -*- objc -*- */

#import "Element.h"

#define SADataChanged @"DataDidChanged"

@interface StoreManager : NSObject
{
  NSMutableDictionary *_stores;
  id _defaultStore;
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
- (id <AgendaStore>)storeContainingElement:(Element *)elt;
- (NSArray *)allEvents;
- (NSArray *)allTasks;
@end
