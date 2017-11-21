/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@class Element;
@class Alarm;

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
  id date;
  id time;
  NSMutableArray *_alarms;
  Alarm *_current;
  Alarm *_simple;
}

+ (NSArray *)editAlarms:(NSArray *)alarms;
- (void)addAlarm:(id)sender;
- (void)removeAlarm:(id)sender;
- (void)changeDelay:(id)sender;
- (void)selectType:(id)sender;
- (void)switchBeforeAfter:(id)sender;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
@end
