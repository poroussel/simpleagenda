/* emacs buffer mode hint -*- objc -*- */

#import "Alarm.h"

@interface AlarmBackend : NSObject
+ (NSString *)backendName;
- (enum icalproperty_action)backendType;
- (void)display:(Alarm *)alarm;
@end
