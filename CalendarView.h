/* emacs objective-c mode -*- objc -*- */

#import <AppKit/AppKit.h>

@interface CalendarView : NSView
{
  NSTextField *title;
  NSButton *obl;
  NSButton *tbl;
  NSButton *obr;
  NSButton *tbr;
  Date *date;
  Date *monthDisplayed;
  NSMatrix *matrix;
  NSFont *normalFont;
  NSFont *boldFont;
  IBOutlet id delegate;
  NSTimer *_dayTimer;
  int bezeledCell;
}

- (id)initWithFrame:(NSRect)frame;
- (Date *)date;
- (NSString *)dateAsString;
- (id)delegate;
- (void)setDate:(Date *)date;
- (void)setDelegate:(id)delegate;
@end

@interface NSObject(CalendarViewDelegate)
- (void)calendarView:(CalendarView *)cs selectedDateChanged:(Date *)date;
- (void)calendarView:(CalendarView *)cs currentDateChanged:(Date *)date;
- (void)calendarView:(CalendarView *)cs userActionForDate:(Date *)date;
@end
