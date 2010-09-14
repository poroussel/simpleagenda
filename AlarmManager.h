/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/NSObject.h>
#import "ConfigManager.h"

NSString * const ACTIVATE_ALARMS;
NSString * const ACTIVATE_DEFAULT_ALARM;
NSString * const DEFAULT_ALARM;

@interface AlarmManager : NSObject <ConfigListener>
{
  NSMutableDictionary *_activeAlarms;
  BOOL _active;
}

+ (AlarmManager *)globalManager;
@end
