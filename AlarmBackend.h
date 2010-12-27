/* emacs buffer mode hint -*- objc -*- */

#import "SAAlarm.h"

@interface AlarmBackend : NSObject
+ (NSString *)backendName;
- (enum icalproperty_action)backendType;
- (void)display:(SAAlarm *)alarm;
@end
