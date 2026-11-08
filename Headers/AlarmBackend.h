/* emacs buffer mode hint -*- objc -*- */

#import "Alarm.h"

@interface AlarmBackend : NSObject
+ (NSString *)backendName;
- (SAAlarmAction)backendType;
- (void)display:(Alarm *)alarm;
@end
