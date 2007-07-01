/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "AgendaStore.h"
#import "StoreManager.h"
#import "ConfigManager.h"
#import "defines.h"

@implementation StoreManager

#define PERSONAL_AGENDA @"Personal Agenda"

- (NSDictionary *)defaults
{
  NSDictionary *local = [NSDictionary
			  dictionaryWithObjects:[NSArray arrayWithObjects:@"LocalStore", @"Personal", nil]
			  forKeys:[NSArray arrayWithObjects:ST_CLASS, ST_FILE, nil]];
  NSDictionary *dict = [NSDictionary 
			 dictionaryWithObjects:[NSArray arrayWithObjects: [NSArray arrayWithObject:PERSONAL_AGENDA], local, PERSONAL_AGENDA, nil]
			 forKeys:[NSArray arrayWithObjects: STORES, PERSONAL_AGENDA, ST_DEFAULT, nil]];
  return dict;
}

- (id)init
{
  Class <AgendaStore> storeClass;
  id <AgendaStore> store;
  NSString *stname;
  NSDictionary *dict;
  NSEnumerator *enumerator;

  self = [super init];
  if (self) {
    [[ConfigManager globalConfig] registerDefaults:[self defaults]];
    [[ConfigManager globalConfig] registerClient:self forKey:ST_DEFAULT];
    NSArray *storeArray = [[ConfigManager globalConfig] objectForKey:STORES];
    NSString *defaultStore = [[ConfigManager globalConfig] objectForKey:ST_DEFAULT];

    _stores = [[NSMutableDictionary alloc] initWithCapacity:1];
    enumerator = [storeArray objectEnumerator];
    while ((stname = [enumerator nextObject])) {
      dict = [[ConfigManager globalConfig] objectForKey:stname];
      if (dict) {
	storeClass = NSClassFromString([dict objectForKey:ST_CLASS]);
	store = [storeClass storeNamed:stname forManager:self];
	if (store) {
	  [_stores setObject:store forKey:stname];
	  NSLog(@"Added %@ to StoreManager", stname);
	  //	  [[ConfigManager globalConfig] registerClient:store forKey:[store description]];
	} else
	  NSLog(@"Unable to initialize store %@", stname);
      }
    }
    [self setDefaultStore:defaultStore];
  }
  return self;
}

- (void)dealloc
{
  [[ConfigManager globalConfig] unregisterClient:self];
  RELEASE(_defaultStore);
  [_stores release];
  [super dealloc];
}

- (void)config:(ConfigManager*)config dataDidChangedForKey:(NSString *)key
{
  [self setDefaultStore:[[ConfigManager globalConfig] objectForKey:ST_DEFAULT]];
}

- (id <AgendaStore>)storeForName:(NSString *)name
{
  return [_stores objectForKey:name];
}

- (void)setDefaultStore:(NSString *)name
{
  id st = [self storeForName:name];
  if (st != nil)
    ASSIGN(_defaultStore, st);
}

- (id <AgendaStore>)defaultStore
{
  return _defaultStore;
}

- (NSEnumerator *)objectEnumerator
{
  return [_stores objectEnumerator];
}

- (void)synchronise
{
  NSEnumerator *enumerator;
  id <AgendaStore> store;

  enumerator = [_stores objectEnumerator];
  while ((store = [enumerator nextObject]))
    if ([store modified] && [store isWritable])
      [store write];
}

@end

