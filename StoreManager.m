/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "AgendaStore.h"
#import "StoreManager.h"
#import "ConfigManager.h"
#import "defines.h"
#import "LocalStore.h"
#import "iCalStore.h"

static NSMutableDictionary *backends = nil;

@implementation StoreManager

#define PERSONAL_AGENDA @"Personal Agenda"

+ (void)initialize
{
  NSArray *classes = GSObjCAllSubclassesOfClass([MemoryStore class]);
  NSEnumerator *enumerator = [classes objectEnumerator];
  Class backendClass;

  if (backends == nil) {
    backends = [[NSMutableDictionary alloc] initWithCapacity:[classes count]];
    while ((backendClass = [enumerator nextObject])) {
      if ([backendClass conformsToProtocol:@protocol(AgendaStore)])
	[backends setObject:backendClass forKey:[backendClass storeTypeName]];
      else
	NSLog(@"Can't register %@ as a store backend", [backendClass description]);
    }
  }
}
+ (NSArray *)backends
{
  return [backends allValues];
}
+ (Class)backendForName:(NSString *)name
{
  return [backends valueForKey:name];
}

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
  NSArray *storeArray;
  NSString *defaultStore;
  NSEnumerator *enumerator;
  NSString *stname;
  ConfigManager *config = [ConfigManager globalConfig];

  self = [super init];
  if (self) {
    [config registerDefaults:[self defaults]];
    storeArray = [config objectForKey:STORES];
    defaultStore = [config objectForKey:ST_DEFAULT];
    _stores = [[NSMutableDictionary alloc] initWithCapacity:1];
    enumerator = [storeArray objectEnumerator];
    while ((stname = [enumerator nextObject]))
      [self addStoreNamed:stname];
    [self setDefaultStore:defaultStore];
    [[NSNotificationCenter defaultCenter] addObserver:self 
					  selector:@selector(dataChanged:) 
					  name:SADataChangedInStore 
					  object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  RELEASE(_defaultStore);
  [_stores release];
  [super dealloc];
}

- (void)dataChanged:(NSNotification *)not
{
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChanged object:self];
}

- (void)addStoreNamed:(NSString *)name
{
  Class storeClass;
  id <AgendaStore> store;
  NSDictionary *dict;

  dict = [[ConfigManager globalConfig] objectForKey:name];
  if (dict) {
    storeClass = NSClassFromString([dict objectForKey:ST_CLASS]);
    store = [storeClass storeNamed:name];
    if (store) {
      [_stores setObject:store forKey:name];
      NSLog(@"Added %@ to StoreManager", name);
      [self dataChanged:nil];
    } else
      NSLog(@"Unable to initialize store %@", name);
  }
}

- (void)removeStoreNamed:(NSString *)name
{
  [_stores removeObjectForKey:name];
  NSLog(@"Removed %@ from StoreManager", name);
  [self dataChanged:nil];
}

- (id <AgendaStore>)storeForName:(NSString *)name
{
  return [_stores objectForKey:name];
}

- (void)setDefaultStore:(NSString *)name
{
  id st = [self storeForName:name];
  if (st != nil) {
    ASSIGN(_defaultStore, st);
    [[ConfigManager globalConfig] setObject:name forKey:ST_DEFAULT];
  }
}

- (id <AgendaStore>)defaultStore
{
  return _defaultStore;
}

- (NSEnumerator *)storeEnumerator
{
  return [_stores objectEnumerator];
}

- (void)synchronise
{
  NSEnumerator *enumerator = [_stores objectEnumerator];
  id <AgendaStore> store;

  while ((store = [enumerator nextObject]))
    [store write];
}

- (id <AgendaStore>)storeContainingElement:(Element *)elt
{
  NSEnumerator *enumerator = [_stores objectEnumerator];
  id <AgendaStore> store;

  while ((store = [enumerator nextObject]))
    if ([store contains:elt])
      return store;
  return nil;
}

- (NSArray *)allEvents
{
  NSMutableArray *all = [NSMutableArray arrayWithCapacity:128];
  NSEnumerator *enumerator = [_stores objectEnumerator];
  id <AgendaStore> store;

  while ((store = [enumerator nextObject]))
    [all addObjectsFromArray:[store events]];
  return all;
}
- (NSArray *)allTasks;
{
  NSMutableArray *all = [NSMutableArray arrayWithCapacity:128];
  NSEnumerator *enumerator = [_stores objectEnumerator];
  id <AgendaStore> store;

  while ((store = [enumerator nextObject]))
    [all addObjectsFromArray:[store tasks]];
  return all;
}
@end

