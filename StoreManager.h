/* emacs buffer mode hint -*- objc -*- */

#import "UserDefaults.h"

@interface StoreManager : NSObject <DefaultsConsumer>
{
  NSMutableDictionary *_stores;
  id _defaultStore;
  id _delegate;
}

- (id <AgendaStore>)storeForName:(NSString *)name;
- (void)setDefaultStore:(NSString *)name;
- (id <AgendaStore>)defaultStore;
- (NSEnumerator *)objectEnumerator;
- (void)setDelegate:(id)delegate;

@end

@interface NSObject(StoreManagerDelegate)
- (void)dataChanged;
@end
