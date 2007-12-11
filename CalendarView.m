/* All Rights reserved */

#import <AppKit/AppKit.h>
#import "Date.h"
#import "CalendarView.h"
#import "StoreManager.h"

static NSImage *circle = nil;

@interface NSCalendarDayCell : NSTextFieldCell
{
  BOOL events;
}
- (void)setEvents:(BOOL)ev;
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
@end
@implementation NSCalendarDayCell
- (void)setEvents:(BOOL)ev
{
  events = ev;
}
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  [super drawInteriorWithFrame:cellFrame inView:controlView];
  if (events)
    [circle compositeToPoint:NSMakePoint(cellFrame.origin.x + 10, cellFrame.origin.y + [circle size].height + 7) operation:NSCompositeSourceOver];
}
@end

@implementation CalendarView
- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  RELEASE(date);
  [_dayTimer invalidate];
  RELEASE(delegate);
  RELEASE(dataSource);
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
    NSArray *months = [[NSUserDefaults standardUserDefaults] objectForKey:NSMonthNameArray];
    NSArray *days = [[NSUserDefaults standardUserDefaults] objectForKey:NSShortWeekDayNameArray];
    boldFont = [NSFont boldSystemFontOfSize: 0];
    normalFont = [NSFont systemFontOfSize: 0];
    delegate = nil;
    dataSource = nil;

    title = [[NSTextField alloc] initWithFrame: NSMakeRect(122, 164, 100, 20)];
    [title setEditable:NO];
    [title setDrawsBackground:NO];
    [title setBezeled:NO];
    [title setBordered:NO];
    [title setSelectable:NO];
    [self addSubview: title];

    button = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(8, 162, 100, 25)];
    [button addItemsWithTitles: months];
    [button setTarget: self];
    [button setAction: @selector(selectMonth:)];
    [self addSubview: button];

    text = [[NSTextField alloc] initWithFrame: NSMakeRect(202, 164, 60, 21)];
    [text setEditable: NO];
    [text setAlignment: NSRightTextAlignment];
    [self addSubview: text];

    stepper = [[NSStepper alloc] initWithFrame: NSMakeRect(266, 162, 16, 25)];
    [stepper setMinValue: 1970];
    [stepper setMaxValue: 2037];
    [stepper setTarget: self];
    [stepper setAction: @selector(selectYear:)];
    [self addSubview: stepper];

    if (!circle) {
      NSString *path = [[NSBundle mainBundle] pathForImageResource:@"check"];
      circle = [[NSImage alloc] initWithContentsOfFile:path];
      [circle setFlipped:YES];
    }

    NSCalendarDayCell *cell = [NSCalendarDayCell new];
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
    [matrix setDoubleAction: @selector(doubleClick:)];
    
    NSColor *orange = [NSColor orangeColor];
    NSColor *white = [NSColor whiteColor];
    for (i = 0; i < 8; i++) {
      cell = [matrix cellAtRow: 0 column: i];
      [cell setAlignment: NSCenterTextAlignment];
      [cell setBackgroundColor: orange];
      [cell setTextColor: white];
      [cell setDrawsBackground: YES];
      if (i < 7 && i > 0)
	[cell setStringValue: [days objectAtIndex: i]];
      else if (i == 7)
	[cell setStringValue: [days objectAtIndex: 0]];
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

    /*
     * FIXME : this should be [Date today] but it leads to
     * every appointment starting at 00:00. Probably a problem 
     * between ical time and ical date
     */
    now = [Date now];
    [self setDate:now];
    [now incrementDay];
    [now setMinute:0];
    _dayTimer = [[NSTimer alloc] initWithFireDate:[now calendarDate]
				 interval:86400 target:self 
				 selector:@selector(dayChanged:) 
				 userInfo:nil 
				 repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_dayTimer forMode:NSDefaultRunLoopMode];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataChanged:) name:SADataChanged object:nil];
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
  NSCalendarDayCell *cell;

  [self clearSelectedDay];
  for (row = 1; row < 7; row++) {
    for (column = 1; column < 8; column++) {
      cell = [matrix cellAtRow: row column: column];
      [cell setStringValue: @""];
      [cell setTag: 0];
      [cell setBackgroundColor: [NSColor clearColor]];
      [cell setEvents:NO];
    }
  }

  today = [[Date today] retain];
  firstWeek = [date copy];
  [firstWeek setDay: 1];
  [firstWeek setMinute:0];
  week = [firstWeek weekOfYear];
  row = 1;
  column = [firstWeek weekday];
  if (!column)
    column = 7;

  for (day = 1; day <= [date numberOfDaysInMonth]; day++) {
    cell = [matrix cellAtRow: row column: column];
    [firstWeek setDay: day];
    if ([firstWeek compare:today] == 0) {
      [cell setBackgroundColor: [NSColor yellowColor]];
      [cell setDrawsBackground: YES];
    }
    if (dataSource && [[dataSource scheduledAppointmentsForDay:firstWeek] count])
      [cell setEvents:YES];
    [cell setIntValue: day];
    [cell setTag: day];
    [cell setFont: normalFont];
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

- (void)doubleClick:(id)sender
{
  if ([delegate respondsToSelector:@selector(calendarView:userActionForDate:)])
    [delegate calendarView:self userActionForDate:date];
}

- (void)setDelegate: (id)aDelegate
{
  ASSIGN(delegate, aDelegate);
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
  return [[date calendarDate] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortDateFormatString]];
}

- (void)setDataSource:(NSObject <AgendaDataSource> *)source
{
  ASSIGN(dataSource, source);
  [self updateView];
}
- (id)dataSource
{
  return dataSource;
}

- (void)dataChanged:(NSNotification *)not
{
  if (dataSource)
    [self updateView];
}
@end
