/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "ConfigManager.h"
#import "Event.h"

@protocol DayViewDataSource
- (NSEnumerator *)scheduledAppointmentsForDayView;
@end

@class AppointmentView;

@interface DayView : NSView <ConfigListener>
{
  id <DayViewDataSource> _dataSource;
  IBOutlet id delegate;
  int _height;
  int _width;
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

- (id)initWithFrame:(NSRect)frameRect;
- (void)drawRect:(NSRect)rect;
- (void)reloadData;
- (Event *)selectedAppointment;
- (int)firstHour;
- (int)lastHour;
- (int)minimumStep;

@end

@interface NSObject(DayViewDelegate)

- (void)doubleClickOnAppointment:(Event *)event;
- (void)modifyAppointment:(Event *)event;
- (void)createAppointmentFrom:(int)start to:(int)end;
- (void)dayView:(DayView *)dayview selectEvent:(Event *)event;

@end
