/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "AgendaStore.h"
#import "StoreManager.h"
#import "defines.h"

@implementation StoreManager

- (id)initWithStores:(NSArray *)array withDefault:(NSString *)name
{
  Class <AgendaStore> storeClass;
  id <AgendaStore> store;
  NSDictionary *dict;
  NSEnumerator *enumerator;

  self = [super init];
  if (self) {
    _stores = [[NSMutableDictionary alloc] initWithCapacity:1];
    enumerator = [array objectEnumerator];
    while ((dict = [enumerator nextObject])) {
      NSLog(@"Adding %@ to StoreManager", [dict objectForKey:ST_CLASS]);
      storeClass = NSClassFromString([dict objectForKey:ST_CLASS]);
      store = [storeClass storeWithParameters:dict forManager:self];
      [_stores setObject:store forKey:[dict objectForKey:ST_NAME]];
    }
    [self setDefaultStore:name];
  }
  return self;
}

- (id)init
{
  return [self initWithStores:[[NSUserDefaults standardUserDefaults] objectForKey:STORES] 
	       withDefault:[[NSUserDefaults standardUserDefaults] objectForKey:ST_DEFAULT]];
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

