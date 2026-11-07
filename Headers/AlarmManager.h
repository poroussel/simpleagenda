/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/NSObject.h>
#import "ConfigManager.h"

extern NSString * const SAEventReminderWillRun;

@interface AlarmManager : NSObject
{
  NSMutableDictionary *_activeAlarms;
  id _defaultBackend;
}

+ (NSArray *)backends;
+ (id)backendForName:(NSString *)name;
+ (AlarmManager *)globalManager;
- (id)defaultBackend;
- (NSString *)defaultBackendName;
- (void)setDefaultBackend:(NSString *)name;
- (BOOL)alarmsEnabled;
- (void)setAlarmsEnabled:(BOOL)value;
@end
