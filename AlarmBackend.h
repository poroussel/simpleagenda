/* emacs buffer mode hint -*- objc -*- */

#import "SAAlarm.h"

@interface AlarmBackend : NSObject
+ (NSString *)backendName;
- (NSString *)backendType;
- (void)display:(SAAlarm *)alarm;
@end
