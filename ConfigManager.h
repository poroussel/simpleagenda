/* emacs buffer mode hint -*- objc -*- */

@class ConfigManager;

@protocol ConfigListener
- (void)config:(ConfigManager *)config dataDidChangedForKey:(NSString *)key;
@end

@interface ConfigManager : NSObject
{
  NSString *_key;
  ConfigManager *_parent;
  NSMutableDictionary *_defaults;
  NSMutableDictionary *_dict;
  NSMutableDictionary *_cpkey;
}

- (ConfigManager *)initForKey:(NSString *)key withParent:(ConfigManager *)parent;
+ (ConfigManager *)globalConfig;
- (void)registerDefaults:(NSDictionary *)defaults;
- (void)registerClient:(id <ConfigListener>)client forKey:(NSString *)key;
- (void)unregisterClient:(id <ConfigListener>)client forKey:(NSString *)key;
- (void)unregisterClient:(id <ConfigListener>)client;
- (id)objectForKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (int)integerForKey:(NSString *)key;
- (void)setInteger:(int)value forKey:(NSString *)key;
- (NSDictionary *)dictionaryForKey:(NSString *)key;
- (void)setDictionary:(NSDictionary *)dict forKey:(NSString *)key;
@end

