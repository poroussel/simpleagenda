/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/NSObject.h>

@interface AlarmManager : NSObject
{
  NSMutableDictionary *_activeAlarms;
}

+ (AlarmManager *)globalManager;
@end
