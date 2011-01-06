/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@class Element;

@interface AlarmEditor : NSObject
{
  id window;
  id panel;
  id type;
  id action;
  id table;
  id add;
  id remove;
  NSMutableArray *_alarms;
}

+ (NSArray *)editAlarms:(NSArray *)alarms;
- (void)addAlarm:(id)sender;
- (void)removeAlarm:(id)sender;
@end
