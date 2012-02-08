/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "ConfigManager.h"
#import "Event.h"
#import "StoreManager.h"
#import "AppointmentView.h"
#import "Date.h"

@interface DayView : NSView
{
  IBOutlet id delegate;
  int _firstH;
  int _lastH;
  int _minStep;
  NSPoint _startPt;
  NSPoint _endPt;
  NSDictionary *_textAttributes;
  AppointmentView *_selected;
  NSColor *_backgroundColor;
  NSColor *_alternateBackgroundColor;
  Date *_date;
}

- (void)selectAppointmentView:(AppointmentView *)aptv;
- (id)delegate;
- (void)reloadData;
- (int)firstHour;
- (int)lastHour;
- (int)minimumStep;
- (void)setDate:(Date *)date;
@end
