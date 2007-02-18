/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>

@protocol DayViewDataSource
- (int)firstHourForDayView;
- (int)lastHourForDayView;
- (NSEnumerator *)scheduledAppointmentsForDayView;
@end

@interface DayView : NSView
{
  id <DayViewDataSource> _dataSource;
  IBOutlet id delegate;
  int _height;
  int _width;
  int _firstH;
  int _lastH;
  NSDictionary *_textAttributes;
  Appointment *_selected;
}

- (id)initWithFrame:(NSRect)frameRect;
- (void)drawRect:(NSRect)rect;
- (void)reloadData;
- (Appointment *)selectedAppointment;

@end

@interface NSObject (DayViewDelegate)

- (void)doubleClickOnAppointment:(Appointment *)apt;

@end
