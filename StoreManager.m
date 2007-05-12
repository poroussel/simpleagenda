/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "AgendaStore.h"
#import "StoreManager.h"
#import "UserDefaults.h"
#import "defines.h"

@implementation StoreManager

UserDefaults *defaults;

- (NSDictionary *)defaults
{
  NSDictionary *local = [NSDictionary
			  dictionaryWithObjects:[NSArray arrayWithObjects:@"LocalStore", @"Personal", @"Personal Agenda", nil]
			  forKeys:[NSArray arrayWithObjects:@"storeClass", @"storeFilename", @"storeName", nil]];
  NSArray *array = [NSArray arrayWithObject:local];
  NSDictionary *dict = [NSDictionary 
			 dictionaryWithObjects:[NSArray arrayWithObjects:[NSArray arrayWithObjects:@"LocalStore", nil], array, @"Personal Agenda", nil]
			 forKeys:[NSArray arrayWithObjects:STORE_CLASSES, STORES, ST_DEFAULT, nil]];
  return dict;
}

- (id)init
{
  Class <AgendaStore> storeClass;
  id <AgendaStore> store;
  NSDictionary *dict;
  NSEnumerator *enumerator;

  self = [super init];
  if (self) {
    defaults = [UserDefaults sharedInstance];
    [defaults setHardDefaults:[self defaults]];
    NSArray *storeArray = [defaults objectForKey:STORES];
    NSString *defaultStore = [defaults objectForKey:ST_DEFAULT];

    _stores = [[NSMutableDictionary alloc] initWithCapacity:1];
    enumerator = [storeArray objectEnumerator];
    while ((dict = [enumerator nextObject])) {
      NSLog(@"Adding %@ to StoreManager", [dict objectForKey:ST_CLASS]);
      storeClass = NSClassFromString([dict objectForKey:ST_CLASS]);
      store = [storeClass storeWithParameters:dict forManager:self];
      [_stores setObject:store forKey:[dict objectForKey:ST_NAME]];
    }
    [self setDefaultStore:defaultStore];
  }
  return self;
}

- (void)dealloc
{
  [_stores release];
  [super dealloc];
}

- (void)defaultDidChanged:(NSString *)name
{
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

