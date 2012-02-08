/* emacs buffer mode hint -*- objc -*- */
#import <Foundation/Foundation.h>

@class ConfigManager;
@class NSColor;

extern NSString * const SAConfigManagerValueChanged;

@interface ConfigManager : NSObject
{
  NSString *_key;
  NSMutableDictionary *_defaults;
}

+ (ConfigManager *)globalConfig;
- (id)initForKey:(NSString *)key;
- (void)registerDefaults:(NSDictionary *)defaults;
- (id)objectForKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (int)integerForKey:(NSString *)key;
- (void)setInteger:(int)value forKey:(NSString *)key;
- (NSColor *)colorForKey:(NSString *)key;
- (void)setColor:(NSColor *)value forKey:(NSString *)key;
@end
