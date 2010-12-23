/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/NSObject.h>
#import "ConfigManager.h"

NSString * const ACTIVATE_ALARMS;
NSString * const DEFAULT_ALARM_BACKEND;

@interface AlarmManager : NSObject <ConfigListener>
{
  NSMutableDictionary *_activeAlarms;
  BOOL _active;
  id _defaultBackend;
}

+ (NSArray *)backends;
+ (id)backendForName:(NSString *)name;
+ (AlarmManager *)globalManager;
- (id)defaultBackend;
- (void)setDefaultBackend:(NSString *)name;
@end
