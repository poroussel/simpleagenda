/* emacs buffer mode hint -*- objc -*- */

#import "SAAlarm.h"

@interface AlarmBackend : NSObject
+ (NSString *)backendName;
- (void)display:(SAAlarm *)alarm;
@end
