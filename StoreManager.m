/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "AgendaStore.h"
#import "StoreManager.h"

@implementation StoreManager

- (id)initWithStores:(NSArray *)array withDefault:(NSString *)name
{
  Class <AgendaStore> storeClass;
  id <AgendaStore> store;
  NSDictionary *dict;
  NSEnumerator *enumerator;

  if ([self init] != nil) {
    _stores = [[NSMutableDictionary alloc] initWithCapacity:1];
    enumerator = [array objectEnumerator];
    while ((dict = [enumerator nextObject])) {
      NSLog(@"Adding %@ to StoreManager", [dict objectForKey:@"storeClass"]);
      storeClass = NSClassFromString([dict objectForKey:@"storeClass"]);
      store = [storeClass storeWithParameters:dict forManager:self];
      [_stores setObject:store forKey:[dict objectForKey:@"storeName"]];
    }
    [self setDefaultStore:name];
  }
  return self;
}

- (void)dealloc
{
  [_stores release];
  [super dealloc];
}

- (id <AgendaStore>)storeForName:(NSString *)name
{
  return [_stores objectForKey:name];
}

- (void)setDefaultStore:(NSString *)name
{
  id st = [self storeForName:name];
  if (st != nil)
    _defaultStore = st;
}

- (id <AgendaStore>)defaultStore
{
  return _defaultStore;
}

- (NSEnumerator *)objectEnumerator
{
  return [_stores objectEnumerator];
}

- (void)dataChanged:(id <AgendaStore>)store
{
  NSLog(@"Data changed in %@", [store description]);
  /* FIXME : do something, like tell the application about the change */
}

@end

