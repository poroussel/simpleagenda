/* emacs buffer mode hint -*- objc -*- */

#import "Event.h"
#import "ConfigManager.h"

@interface StoreManager : NSObject <ConfigListener>
{
  NSMutableDictionary *_backends;
  NSMutableDictionary *_stores;
  id _defaultStore;
  id _delegate;
}

- (void)registerBackend:(Class)type;
- (NSArray *)registeredBackends;
- (Class)backendNamed:(NSString *)name;
- (void)addStoreNamed:(NSString *)name;
- (void)addStore:(id <AgendaStore>)store ForName:(NSString *)name;
- (void)removeStoreNamed:(NSString *)name;
- (id <AgendaStore>)storeForName:(NSString *)name;
- (void)setDefaultStore:(NSString *)name;
- (id <AgendaStore>)defaultStore;
- (NSEnumerator *)storeEnumerator;
- (void)synchronise;

- (void)setDelegate:(id)delegate;
- (id)delegate;

- (id <AgendaStore>)storeContainingEvent:(Event *)event;
- (NSArray *)allEvents;
@end

@interface NSObject(StoreManagerDelegate)
- (void)dataChangedInStoreManager:(StoreManager *)sm;
@end
