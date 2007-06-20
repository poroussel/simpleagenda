/* emacs buffer mode hint -*- objc -*- */

#import "UserDefaults.h"

@interface StoreManager : NSObject <DefaultsConsumer>
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
