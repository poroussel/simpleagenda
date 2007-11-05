/* emacs objective-c mode -*- objc -*- */

#import <AppKit/AppKit.h>

@interface CalendarView : NSView
{
  NSTextField *title;
  Date *date;
  NSPopUpButton *button;
  NSStepper *stepper;
  NSTextField *text;
  NSMatrix *matrix;
  NSFont *normalFont;
  NSFont *boldFont;
  IBOutlet id delegate;
  NSTimer *_dayTimer;
}

- (id)initWithFrame:(NSRect)frame;
- (Date *)date;
- (NSString *)dateAsString;
- (id)delegate;
- (void)setDate:(Date *)date;
- (void)setDelegate:(id)aDelegate;

@end

@interface NSObject(CalendarViewDelegate)

- (void)calendarView:(CalendarView *)cs selectedDateChanged:(Date *)date;
- (void)calendarView:(CalendarView *)cs currentDateChanged:(Date *)date;

@end
