#import <Foundation/Foundation.h>
#import "ConfigManager.h"

static ConfigManager *singleton;
static NSMutableDictionary *_cpkey;

@implementation ConfigManager(Private)
- (ConfigManager *)initRoot
{
  self = [super init];
  if (self) {
    _dict = [NSMutableDictionary new];
    _defaults = [NSMutableDictionary new];
    [_dict setDictionary:[[NSUserDefaults standardUserDefaults] 
			   persistentDomainForName:[[NSProcessInfo processInfo] processName]]];
  }
  return self;
}
@end

@implementation ConfigManager
+ (void)initialize
{
  if ([ConfigManager class] == self) {
    _cpkey = [NSMutableDictionary new];
    singleton = [[ConfigManager alloc] initRoot];
  }
}

- (ConfigManager *)initForKey:(NSString *)key withParent:(ConfigManager *)parent
{
  NSAssert(key != nil, @"ConfigManager initForKey called with nil key");
  self = [super init];
  if (self) {
    _dict = [NSMutableDictionary new];
    _defaults = [NSMutableDictionary new];
    if (parent == nil)
      parent = [ConfigManager globalConfig];
    [_dict setDictionary:[parent dictionaryForKey:key]];
    ASSIGN(_parent, parent);
    ASSIGNCOPY(_key, key);
  }
  return self;
}

+ (ConfigManager *)globalConfig
{
  return singleton;
}

- (void)dealloc
{
  RELEASE(_key);
  RELEASE(_parent);
  [_defaults release];
  [_dict release];
  [super dealloc];
}

- (void)notifyListenerForKey:(NSString *)key
{
  NSEnumerator *enumerator;
  id <ConfigListener> listener;
  NSValue *value;

  NSAssert(key != nil, @"Missing key");
  enumerator = [[_cpkey objectForKey:key] objectEnumerator];
  while ((value = [enumerator nextObject])) {
    listener = [value nonretainedObjectValue];
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
  id object;

  object = [self objectForKey:key];
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
  id object;

  object = [self objectForKey:key];
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

- (void)registerClient:(id <ConfigListener>)client forKey:(NSString*)key
{
  NSAssert(key != nil, @"You have to register for a specific key");
  NSMutableSet *listeners = [_cpkey objectForKey:key];

  if (listeners)
    [listeners addObject:[NSValue valueWithNonretainedObject:client]];
  else
    listeners = [NSMutableSet setWithObject:[NSValue valueWithNonretainedObject:client]];
  [_cpkey setObject:listeners forKey:key];
 
}

- (void)unregisterClient:(id <ConfigListener>)client forKey:(NSString*)key
{
  NSMutableSet *set = [_cpkey objectForKey:key];
  NSSet *copy;
  NSEnumerator *enumerator;
  NSValue *v;

  if (set) {
    copy = [NSSet setWithSet:set];
    enumerator = [copy objectEnumerator];
    while ((v = [enumerator nextObject])) {
      if (client == [v nonretainedObjectValue])
	[set removeObject:v];
    }
  }
}

- (void)unregisterClient:(id <ConfigListener>)client
{
  NSMutableSet *set;
  NSSet *copy;
  NSValue *v;
  NSEnumerator *enumerator = [_cpkey objectEnumerator];
  NSEnumerator *en;

  while ((set = [enumerator nextObject])) {
    copy = [NSSet setWithSet:set];
    en = [copy objectEnumerator];
    while ((v = [en nextObject])) {
      if (client == [v nonretainedObjectValue])
	[set removeObject:v];
    }
  }
}
@end
