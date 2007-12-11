/* emacs objective-c mode -*- objc -*- */

#import <AppKit/AppKit.h>
#import "StoreManager.h"

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
  IBOutlet NSObject <AgendaDataSource> *dataSource;
  NSTimer *_dayTimer;
}

- (id)initWithFrame:(NSRect)frame;
- (Date *)date;
- (NSString *)dateAsString;
- (id)delegate;
- (id)dataSource;
- (void)setDate:(Date *)date;
- (void)setDelegate:(id)delegate;
- (void)setDataSource:(NSObject <AgendaDataSource> *)source;
@end

@interface NSObject(CalendarViewDelegate)
- (void)calendarView:(CalendarView *)cs selectedDateChanged:(Date *)date;
- (void)calendarView:(CalendarView *)cs currentDateChanged:(Date *)date;
- (void)calendarView:(CalendarView *)cs userActionForDate:(Date *)date;
@end
