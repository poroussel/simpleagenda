/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "Event.h"

@protocol DayViewDataSource
- (int)firstHourForDayView;
- (int)lastHourForDayView;
- (int)minimumStepForDayView;
- (NSEnumerator *)scheduledAppointmentsForDayView;
@end

@class AppointmentView;

@interface DayView : NSView
{
  id <DayViewDataSource> _dataSource;
  IBOutlet id delegate;
  int _height;
  int _width;
  int _firstH;
  int _lastH;
  NSPoint _startPt;
  NSPoint _endPt;
  NSDictionary *_textAttributes;
  AppointmentView *_selected;
}

- (id)initWithFrame:(NSRect)frameRect;
- (void)drawRect:(NSRect)rect;
- (void)reloadData;
- (Event *)selectedAppointment;

@end

@interface NSObject (DayViewDelegate)

- (void)doubleClickOnAppointment:(Event *)apt;
- (void)modifyAppointment:(Event *)apt;
- (void)createAppointmentFrom:(int)start to:(int)end;

@end
