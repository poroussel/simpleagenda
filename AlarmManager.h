/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/NSObject.h>
#import "ConfigManager.h"

@interface AlarmManager : NSObject <ConfigListener>
{
  NSMutableDictionary *_activeAlarms;
  BOOL _active;
}

+ (AlarmManager *)globalManager;
@end
