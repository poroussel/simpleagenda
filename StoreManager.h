/* emacs buffer mode hint -*- objc -*- */

#import "ConfigManager.h"

@interface StoreManager : NSObject <ConfigListener>
{
  NSMutableDictionary *_stores;
  id _defaultStore;
}

- (id <AgendaStore>)storeForName:(NSString *)name;
- (void)setDefaultStore:(NSString *)name;
- (id <AgendaStore>)defaultStore;
- (NSEnumerator *)objectEnumerator;
- (void)synchronise;

@end
