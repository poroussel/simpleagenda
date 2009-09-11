/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "ConfigManager.h"
#import "Event.h"
#import "StoreManager.h"
#import "AppointmentView.h"

@interface DayView : NSView <ConfigListener>
{
  IBOutlet id <AgendaDataSource> dataSource;
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
}

- (void)selectAppointmentView:(AppointmentView *)aptv;
- (NSRect)frameForAppointment:(Event *)apt;
- (int)minuteToPosition:(int)minutes;
- (int)positionToMinute:(float)position;
- (int)roundMinutes:(int)minutes;
- (id)delegate;
- (void)reloadData;
- (int)firstHour;
- (int)lastHour;
- (int)minimumStep;
@end
