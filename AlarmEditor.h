/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@class Element;
@class SAAlarm;

@interface AlarmEditor : NSObject
{
  id window;
  id panel;
  id type;
  id action;
  id table;
  id add;
  id remove;
  id relativeSlider;
  id relativeText;
  id radio;
  NSMutableArray *_alarms;
  SAAlarm *_current;
  SAAlarm *_simple;
}

+ (NSArray *)editAlarms:(NSArray *)alarms;
- (void)addAlarm:(id)sender;
- (void)removeAlarm:(id)sender;
- (void)changeDelay:(id)sender;
- (void)switchBeforeAfter:(id)sender;
@end
