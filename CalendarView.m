/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "Date.h"
#include "CalendarView.h"

@implementation CalendarView

- (void)dealloc
{
  RELEASE(date);
  [_dayTimer invalidate];
  delegate = nil;
  [boldFont release];
  [normalFont release];
  [title release];
  [matrix release];
  [button release];
  [stepper release];
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frame
{
  int i;
  Date *now;

  self = [super initWithFrame:frame];

  if (self) {
    NSArray *months = [[NSArray alloc] initWithObjects: _(@"January"),
				       _(@"February"),
				       _(@"March"),
				       _(@"April"),
				       _(@"May"), 
				       _(@"June"),
				       _(@"July"),
				       _(@"August"),
				       _(@"September"),
				       _(@"October"),
				       _(@"November"),
				       _(@"December"),
				       nil];

    NSArray *days = [[NSArray alloc] initWithObjects: @"",
				     _(@"mon"),
				     _(@"tue"),
				     _(@"wed"),
				     _(@"thu"),
				     _(@"fri"),
				     _(@"sat"),
				     _(@"sun"), 
				     nil];
    boldFont = [NSFont boldSystemFontOfSize: 0];
    normalFont = [NSFont systemFontOfSize: 0];
    delegate = nil;

    title = [[NSTextField alloc] initWithFrame: NSMakeRect(120, 200, 100, 20)];
    [title setEditable:NO];
    [title setDrawsBackground:NO];
    [title setBezeled:NO];
    [title setBordered:NO];
    [title setSelectable:NO];
    [self addSubview: title];

    button = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(8, 170, 100, 25)];
    [button addItemsWithTitles: months];
    [button setTarget: self];
    [button setAction: @selector(selectMonth:)];
    [self addSubview: button];

    text = [[NSTextField alloc] initWithFrame: NSMakeRect(202, 172, 60, 21)];
    [text setEditable: NO];
    [text setAlignment: NSRightTextAlignment];
    [self addSubview: text];

    stepper = [[NSStepper alloc] initWithFrame: NSMakeRect(266, 170, 16, 25)];
    [stepper setMinValue: 1970];
    [stepper setMaxValue: 2037];
    [stepper setTarget: self];
    [stepper setAction: @selector(selectYear:)];
    [self addSubview: stepper];

    NSTextFieldCell *cell = [NSTextFieldCell new];
    [cell setEditable: NO];
    [cell setSelectable: NO];
    [cell setAlignment: NSRightTextAlignment];

    matrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(9, 8, 280, 150)
			       mode: NSListModeMatrix
			       prototype: cell
			       numberOfRows: 7
			       numberOfColumns: 8];
    [matrix setIntercellSpacing: NSZeroSize];
    [matrix setDelegate:self];
    [matrix setAction: @selector(selectDay:)];
    
    NSColor *orange = [NSColor orangeColor];
    NSColor *white = [NSColor whiteColor];
    for (i = 0; i < 8; i++) {
      cell = [matrix cellAtRow: 0 column: i];
      [cell setAlignment: NSCenterTextAlignment];
      [cell setBackgroundColor: orange];
      [cell setTextColor: white];
      [cell setDrawsBackground: YES];
      [cell setStringValue: [days objectAtIndex: i]];
    }
    for (i = 0; i < 7; i++) {
      cell = [matrix cellAtRow: i column: 0];
      [cell setBackgroundColor: orange];
      [cell setTextColor: white];
      [cell setDrawsBackground: YES];
    }
    [orange release];
    [white release];
    [self addSubview: matrix];

    //[self setTitlePosition:NSBelowTop];
    now = [Date date];
    [self setDate:now];
    [now incrementDay];
    [now setMinute:0];
    _dayTimer = [[NSTimer alloc] initWithFireDate:[now calendarDate]
				 interval:86400 target:self 
				 selector:@selector(dayChanged:) 
				 userInfo:nil 
				 repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_dayTimer forMode:NSDefaultRunLoopMode];
  }
  return self;

}

- (void)updateTitle
{
  [title setStringValue:[self dateAsString]];
}

- (void)clearSelectedDay
{
  [[matrix cellWithTag: [date dayOfMonth]] setFont: normalFont];
}

- (void)setSelectedDay
{
  [[matrix cellWithTag: [date dayOfMonth]] setFont: boldFont];
  [self updateTitle];

  if ([delegate respondsToSelector:@selector(calendarView:selectedDateChanged:)])
    [delegate calendarView:self selectedDateChanged:date];
}

- (void)updateView
{
  int day, row, column, week;
  Date *firstWeek;
  Date *today;

  [self clearSelectedDay];
  for (row = 1; row < 7; row++) {
    for (column = 1; column < 8; column++) {
      [[matrix cellAtRow: row column: column] setStringValue: @""];
      [[matrix cellAtRow: row column: column] setTag: 0];
      [[matrix cellAtRow: row column: column] setBackgroundColor: [NSColor clearColor]];
    }
  }

  today = [Date new];
  [today setMinute:0];
  firstWeek = [date copy];
  [firstWeek setDay: 1];
  [firstWeek setMinute:0];
  week = [firstWeek weekOfYear];
  row = 1;
  column = [firstWeek weekday];
  if (!column)
    column = 7;

  for (day = 1; day <= [date numberOfDaysInMonth]; day++) {
    [firstWeek setDay: day];
    if ([firstWeek compare:today] == 0) {
      [[matrix cellAtRow: row column: column] setBackgroundColor: [NSColor yellowColor]];
      [[matrix cellAtRow: row column: column] setDrawsBackground: YES];
    }
    [[matrix cellAtRow: row column: column] setIntValue: day];
    [[matrix cellAtRow: row column: column] setTag: day];
    [[matrix cellAtRow: row column: column] setFont: normalFont];
    [[matrix cellAtRow: row column: 0] setStringValue: [NSString stringWithFormat: @"%d ", week]];
    column++;
    if (column > 7) {
      column = 1;
      row++;
      week++;
    }
  }
  [self setSelectedDay];
  [firstWeek release];
  [today release];
}

- (void)dayChanged:(NSTimer *)timer
{
  Date *today = [Date new];
  [self updateView];
  if ([delegate respondsToSelector:@selector(calendarView:currentDateChanged:)])
    [delegate calendarView:self currentDateChanged:today];
  [today release];
}

- (void)selectMonth: (id)sender
{
  int month = [button indexOfSelectedItem] + 1;
  
  [date setMonth: month];
  [self updateView];
}

- (void)selectYear: (id)sender
{
  int year = [stepper intValue];
  
  [text setIntValue: year];
  [date setYear: year];
  [self updateView];
}

- (void)selectDay: (id)sender
{
  int day = [[matrix selectedCell] tag];
  if (day > 0) {
    [self clearSelectedDay];
    [date setDay: day];
    [self setSelectedDay];
  }
}

- (void)setDelegate: (id)aDelegate
{
  delegate = aDelegate;
}

- (id)delegate
{
  return delegate;

}

- (void)setDate:(Date *)nDate
{
  ASSIGNCOPY(date, nDate);
  [text setIntValue: [date year]];
  [stepper setIntValue: [date year]];
  [button selectItemAtIndex: [date monthOfYear] - 1];
  [self updateView];
}

- (Date *)date
{
  return date;
}

- (NSString *)dateAsString
{
  return [[date calendarDate] descriptionWithCalendarFormat: @"%Y/%m/%d"];
}

@end
