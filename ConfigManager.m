#import <Foundation/Foundation.h>
#import "NSColor+SimpleAgenda.h"
#import "ConfigManager.h"

NSString * const SAConfigManagerValueChanged = @"SAConfigManagerValueChanged";

static ConfigManager *singleton;
static NSUserDefaults *appDefaults;

@implementation ConfigManager
+ (void)initialize
{
  if ([ConfigManager class] == self) {
    singleton = [ConfigManager new];
    appDefaults = [NSUserDefaults standardUserDefaults];
  }
}

+ (ConfigManager *)globalConfig
{
  return singleton;
}

- (id)init
{
  if ((self = [super init]))
    _defaults = [NSMutableDictionary new];
  return self;
}

- (id)initForKey:(NSString *)key
{
  if ((self = [self init]))
    ASSIGNCOPY(_key, key);
  return self;
}

- (void)dealloc
{
  DESTROY(_defaults);
  DESTROY(_key);
  [super dealloc];
}

- (void)registerDefaults:(NSDictionary *)defaults
{
  [_defaults addEntriesFromDictionary:defaults];
}

- (id)objectForKey:(NSString *)key
{
  id value = _key ? [[appDefaults dictionaryForKey:_key] objectForKey:key] : [appDefaults objectForKey:key];
  return value ? value : [_defaults objectForKey:key];
}

- (void)removeObjectForKey:(NSString *)key
{
  NSMutableDictionary *mdict;

  if (_key) {
    mdict = [NSMutableDictionary dictionaryWithDictionary:[appDefaults objectForKey:_key]];
    [mdict removeObjectForKey:key];
    [appDefaults setObject:mdict forKey:_key];
    [[NSNotificationCenter defaultCenter] postNotificationName:SAConfigManagerValueChanged
							object:self
						      userInfo:[NSDictionary dictionaryWithObject:_key forKey:@"key"]];
  } else
    [appDefaults removeObjectForKey:key];
  [appDefaults synchronize];
}

- (void)setObject:(id)value forKey:(NSString *)key
{
  NSMutableDictionary *mdict;

  if (_key) {
    mdict = [NSMutableDictionary dictionaryWithDictionary:[appDefaults objectForKey:_key]];
    [mdict setObject:value forKey:key];
    [appDefaults setObject:mdict forKey:_key];
  } else
    [appDefaults setObject:value forKey:key];
  [[NSNotificationCenter defaultCenter] postNotificationName:SAConfigManagerValueChanged
						      object:self
						    userInfo:[NSDictionary dictionaryWithObject:key forKey:@"key"]];
  [appDefaults synchronize];
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
@end
