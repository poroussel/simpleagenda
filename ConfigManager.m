#import <Foundation/Foundation.h>
#import "NSColor+SimpleAgenda.h"
#import "ConfigManager.h"

static ConfigManager *singleton;
static NSMutableDictionary *cpkey;

@implementation ConfigManager(Private)
- (ConfigManager *)initRoot
{
  if ((self = [self init]))
      [_dict setDictionary:[[NSUserDefaults standardUserDefaults] 
			     persistentDomainForName:[[NSProcessInfo processInfo] processName]]];
  return self;
}
@end

@implementation ConfigManager
+ (void)initialize
{
  if ([ConfigManager class] == self) {
    cpkey = [NSMutableDictionary new];
    singleton = [[ConfigManager alloc] initRoot];
  }
}

+ (ConfigManager *)globalConfig
{
  return singleton;
}

- (id)init
{
  if ((self = [super init])) {
    _dict = [NSMutableDictionary new];
    _defaults = [NSMutableDictionary new];
  }
  return self;
}

- (id)initForKey:(NSString *)key
{
  ConfigManager *parent = [ConfigManager globalConfig];

  if ((self = [self init])) {
    [_dict setDictionary:[parent dictionaryForKey:key]];
    ASSIGN(_parent, parent);
    ASSIGNCOPY(_key, key);
  }
  return self;
}

- (void)dealloc
{
  DESTROY(_key);
  DESTROY(_parent);
  DESTROY(_defaults);
  DESTROY(_dict);
  [super dealloc];
}

- (void)notifyListenerForKey:(NSString *)key
{
  id <ConfigListener> listener;
  NSPointerArray *array;
  NSUInteger index;

  array = [cpkey objectForKey:key];
  for (index = 0; index < [array count]; index++) {
    listener = [array pointerAtIndex:index];
    if (listener)
      [listener config:self dataDidChangedForKey:key];
  }
}

- (void)registerDefaults:(NSDictionary *)defaults
{
  [_defaults addEntriesFromDictionary:defaults];
}

- (id)objectForKey:(NSString *)key
{
  id obj = [_dict objectForKey:key];

  if (obj)
    return obj;
  return [_defaults objectForKey:key];
}

- (void)removeObjectForKey:(NSString *)key
{
  [_dict removeObjectForKey:key];
  [self notifyListenerForKey:key];
  if (_parent)
    [_parent setObject:_dict forKey:_key];
  else
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}

- (void)setObject:(id)value forKey:(NSString *)key
{
  [_dict setObject:value forKey:key];
  [self notifyListenerForKey:key];
  if (_parent)
    [_parent setObject:_dict forKey:_key];
  else
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
}

- (int)integerForKey:(NSString *)key
{
  id object = [self objectForKey:key];

  if (object != nil)
    return [object intValue];
  return 0;
}

- (void)setInteger:(int)value forKey:(NSString *)key
{
  [self setObject:[NSNumber numberWithInt:value] forKey:key];
}

- (NSDictionary *)dictionaryForKey:(NSString *)key
{
  id object = [self objectForKey:key];

  if (object != nil && [object isKindOfClass:[NSDictionary class]])
    return object;
  return nil;
}

- (void)setDictionary:(NSDictionary *)dict forKey:(NSString *)key
{
  [self setObject:dict forKey:key];
}

- (NSColor *)colorForKey:(NSString *)key
{
  id obj = [self objectForKey:key];

  if ([obj isKindOfClass:[NSData class]])
    return [NSUnarchiver unarchiveObjectWithData:obj];
  return [NSColor colorFromString:obj];
}

- (void)setColor:(NSColor *)value forKey:(NSString *)key
{
  [self setObject:[value description] forKey:key];
}

- (void)registerClient:(id <ConfigListener>)client forKey:(NSString *)key
{
  NSPointerArray *listeners = [cpkey objectForKey:key];

  if (!listeners) {
    listeners = [NSPointerArray pointerArrayWithWeakObjects];
    [cpkey setObject:listeners forKey:key];
  }
  [listeners addPointer:client];
}

- (void)unregisterClient:(id <ConfigListener>)client forKey:(NSString *)key
{
  NSPointerArray *array = [cpkey objectForKey:key];
  NSUInteger index;

  if (array) {
    for (index = 0; index < [array count]; index++) {
      if ([array pointerAtIndex:index] == client)
	[array replacePointerAtIndex:index withPointer:NULL];
    }
    [array compact];
  }
}

- (void)unregisterClient:(id <ConfigListener>)client
{
  NSEnumerator *enumerator = [cpkey objectEnumerator];
  NSPointerArray *array;
  NSUInteger index;

  while ((array = [enumerator nextObject])) {
    for (index = 0; index < [array count]; index++) {
      if ([array pointerAtIndex:index] == client)
	[array replacePointerAtIndex:index withPointer:NULL];
    }
    [array compact];
  }
}
@end
