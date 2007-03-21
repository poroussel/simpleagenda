/* emacs buffer mode hint -*- objc -*- */

@interface StoreManager : NSObject
{
  NSMutableDictionary *_stores;
  id _defaultStore;
}

- (id)init;
- (id)initWithStores:(NSArray *)array withDefault:(NSString *)name;
- (id <AgendaStore>)storeForName:(NSString *)name;
- (void)setDefaultStore:(NSString *)name;
- (id <AgendaStore>)defaultStore;
- (NSEnumerator *)objectEnumerator;

@end
