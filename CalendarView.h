/* emacs objective-c mode -*- objc -*- */

#import <AppKit/AppKit.h>

typedef enum {
  CVEmptyCell = 0,
  CVHasDataCell
} CVCellStatus;

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
  id _dataSource;
}

- (id)initWithFrame:(NSRect)frame;
- (Date *)date;
- (void)setDate:(Date *)date;
- (NSString *)dateAsString;
- (id)delegate;
- (void)setDelegate:(id)delegate;
- (id)dataSource;
- (void)setDataSource:(id)dataSource;
- (void)reloadData;
@end

@interface NSObject(CalendarViewDelegate)
- (void)calendarView:(CalendarView *)cs selectedDateChanged:(Date *)date;
- (void)calendarView:(CalendarView *)cs currentDateChanged:(Date *)date;
- (void)calendarView:(CalendarView *)cs userActionForDate:(Date *)date;
@end

@interface NSObject(CalendarViewDataSource)
- (CVCellStatus)calendarView:(CalendarView *)view cellStatusForDate:(Date *)date;
@end
