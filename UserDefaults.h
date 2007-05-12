/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@protocol DefaultsConsumer
- (void)defaultDidChanged:(NSString *)name;
@end

@interface UserDefaults : NSObject
{
  NSMutableDictionary *_cpkey;
  NSUserDefaults *_defaults;
}

+ (UserDefaults *)sharedInstance;
- (void)dealloc;
- (void)setHardDefaults:(NSDictionary *)def;
- (id)objectForKey:(NSString *)name;
- (int)integerForKey:(NSString *)name;
- (void)setInteger:(int)value forKey:(NSString*)key;
- (void)setObject:(id)value forKey:(NSString*)key;
- (void)registerClient:(id <DefaultsConsumer>)client forKey:(NSString*)key;
- (void)unregisterClient:(id <DefaultsConsumer>)client;

@end

