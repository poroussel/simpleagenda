/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@interface AlarmEditor : NSObject
{
  id panel;
  id calendar;
  id type;
  id action;
}

- (void)show;
@end
