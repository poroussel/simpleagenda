/* emacs buffer mode hint -*- objc -*- */

#import "Event.h"
#import "ConfigManager.h"

@interface StoreManager : NSObject <ConfigListener>
{
  NSMutableDictionary *_stores;
  id _defaultStore;
}

- (void)addStoreNamed:(NSString *)name;
- (void)removeStoreNamed:(NSString *)name;
- (id <AgendaStore>)storeForName:(NSString *)name;
- (void)setDefaultStore:(NSString *)name;
- (id <AgendaStore>)defaultStore;
- (NSEnumerator *)storeEnumerator;
- (void)synchronise;

- (id <AgendaStore>)storeContainingEvent:(Event *)event;
- (NSArray *)allEvents;
@end
