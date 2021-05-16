#import <AppKit/AppKit.h>
#import "defines.h"
#import "Date.h"
#import "CalendarView.h"
#import "ConfigManager.h"
#import "StoreManager.h"

@interface DayFormatter : NSFormatter
@end
@implementation DayFormatter
- (NSString *)stringForObjectValue:(id)anObject
{
  NSAssert([anObject isKindOfClass:[Date class]], @"Needs a Date as input");
  return [NSString stringWithFormat:@"%2d", [(Date *)anObject dayOfMonth]];
}
- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
  return NO;
}
- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes
{
  return nil;
}
@end

static int WEEKDAYSTOP = 1;

@implementation CalendarView
static NSImage *_1left;
static NSImage *_2left;
static NSImage *_1right;
static NSImage *_2right;
+ (void)initialize
{
  _1left = [NSImage imageNamed:@"1left.tiff"];
  _2left = [NSImage imageNamed:@"2left.tiff"];
  _1right = [NSImage imageNamed:@"1right.tiff"];
  _2right = [NSImage imageNamed:@"2right.tiff"];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_dayTimer invalidate];
  RELEASE(date);
  RELEASE(monthDisplayed);
  RELEASE(_dayTimer);
  RELEASE(delegate);
  RELEASE(_dataSource);
  RELEASE(boldFont);
  RELEASE(normalFont);
  RELEASE(title);
  RELEASE(matrix);
  RELEASE(obl);
  RELEASE(tbl);
  RELEASE(obr);
  RELEASE(tbr);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frame
{
  int i;
  int j;
  int tag;
  Date *now;
  DayFormatter *formatter;

  self = [super initWithFrame:frame];
  if (self) {
    NSString *direction = [[ConfigManager globalConfig] objectForKey:CAL_DIRECTION];
    WEEKDAYSTOP = ![direction isEqualToString:CAL_VERTICAL];

    NSArray *days = [[NSUserDefaults standardUserDefaults] objectForKey:NSShortWeekDayNameArray];
    boldFont = RETAIN([NSFont boldSystemFontOfSize:11]);
    normalFont = RETAIN([NSFont systemFontOfSize:11]);

    title = [[NSTextField alloc] initWithFrame: NSMakeRect(32, 125, 168, 20)];
    [title setEditable:NO];
    [title setDrawsBackground:NO];
    [title setBezeled:NO];
    [title setBordered:NO];
    [title setSelectable:NO];
    [title setFont:normalFont];
    [title setAlignment: NSCenterTextAlignment];
    [self addSubview: title];

    tbl = [[NSButton alloc] initWithFrame:NSMakeRect(9, 128, 12, 20)];
    [tbl setImage:_2left];
    [tbl setBordered:NO];
    [tbl setTarget:self];
    [tbl setAction:@selector(previousYear:)];
    [self addSubview:tbl];
    obl = [[NSButton alloc] initWithFrame:NSMakeRect(22, 128, 12, 20)];
    [obl setImage:_1left];
    [obl setBordered:NO];
    [obl setTarget:self];
    [obl setAction:@selector(previousMonth:)];
    [self addSubview:obl];
    obr = [[NSButton alloc] initWithFrame:NSMakeRect(201, 128, 12, 20)];
    [obr setButtonType:NSMomentaryPushInButton];
    [obr setImage:_1right];
    [obr setBordered:NO];
    [obr setTarget:self];
    [obr setAction:@selector(nextMonth:)];
    [self addSubview:obr];
    tbr = [[NSButton alloc] initWithFrame:NSMakeRect(214, 128, 12, 20)];
    [tbr setImage:_2right];
    [tbr setBordered:NO];
    [tbr setTarget:self];
    [tbr setAction:@selector(nextYear:)];
    [self addSubview:tbr];

    NSTextFieldCell *cell = [NSTextFieldCell new];
    [cell setEditable: NO];
    [cell setSelectable: NO];
    [cell setAlignment: NSRightTextAlignment];
    [cell setFont:normalFont];

    matrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(9, 6, 220, 128)
			       mode: NSListModeMatrix
			       prototype: cell
			       numberOfRows: WEEKDAYSTOP ? 7 : 8
			       numberOfColumns: WEEKDAYSTOP ? 8 : 7];
    [matrix setIntercellSpacing: NSZeroSize];
    [matrix setDelegate:self];
    [matrix setAction: @selector(selectDay:)];
    [matrix setDoubleAction: @selector(doubleClick:)];

    NSColor *orange = [NSColor orangeColor];
    NSColor *white = [NSColor whiteColor];
    for (i = 0; i < 8; i++) {
      cell = [matrix cellAtRow: WEEKDAYSTOP ? 0 : i column: WEEKDAYSTOP ? i : 0];
      [cell setBackgroundColor: orange];
      [cell setTextColor: white];
      [cell setDrawsBackground: YES];
      if (i < 7 && i > 0)
	[cell setStringValue: [[days objectAtIndex: i] substringToIndex:1]];
      else if (i == 7)
	[cell setStringValue: [[days objectAtIndex: 0] substringToIndex:1]];
    }
    for (i = 0; i < 7; i++) {
      cell = [matrix cellAtRow: WEEKDAYSTOP ? i : 0 column: WEEKDAYSTOP ? 0 : i];
      [cell setBackgroundColor: orange];
      [cell setTextColor: white];
      [cell setDrawsBackground: YES];
    }
    formatter = [DayFormatter new];
    for (i = 1, tag = 1; i < 8; i++) {
      for (j = 1; j < 7; j++) {
	[[matrix cellAtRow: WEEKDAYSTOP ? j : i column: WEEKDAYSTOP ? i : j] setFormatter:formatter];
	[[matrix cellAtRow: WEEKDAYSTOP ? j : i column: WEEKDAYSTOP ? i : j] setTag:tag++];
      }
    }
    [formatter release];
    [self addSubview: matrix];

    _dataSource = nil;

    now = [Date today];
    [self setDate:now];
    [now incrementDay];
    _dayTimer = [[NSTimer alloc] initWithFireDate:[now calendarDate]
				         interval:86400
				           target:self
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
  [[matrix cellWithTag:bezeledCell] setBezeled:NO];
}

- (void)setSelectedDay
{
  NSCell *cell;
  int i, j;
  id object;

  for (i = 1; i < 8; i++) {
    for (j = 1; j < 7; j++) {
      cell = [matrix cellAtRow:WEEKDAYSTOP ? j : i column:WEEKDAYSTOP ? i : j];
      object = [cell objectValue];
      if (object != nil && ![date compare:object withTime:NO]) {
	bezeledCell = [cell tag];
	[cell setBezeled:YES];
	[self updateTitle];
	return;
      }
    }
  }
}

- (void)updateView
{
  int row, column, week;
  Date *day, *today;
  NSTextFieldCell *cell;
  NSColor *clear = [NSColor clearColor];
  NSColor *white = [NSColor whiteColor];
  NSColor *black = [NSColor blackColor];

  [self clearSelectedDay];
  today = [Date today];
  day = [monthDisplayed copy];
  [day setDay: 1];
  column = [day weekday];
  [day changeDayBy:1-column];
  for (row = 1; row < 7; row++) {
    week = [day weekOfYear];
    [[matrix cellAtRow:WEEKDAYSTOP ? row : 0 column:WEEKDAYSTOP ? 0 : row] setStringValue:[NSString stringWithFormat:@"%d ", week]];
    for (column = 1; column < 8; column++, [day incrementDay]) {
      cell = [matrix cellAtRow: WEEKDAYSTOP ? row : column column: WEEKDAYSTOP ? column : row];
      if ([day compare:today withTime:NO] == 0) {
	[cell setBackgroundColor:[NSColor yellowColor]];
	[cell setDrawsBackground:YES];
      } else {
	[cell setBackgroundColor:clear];
	[cell setDrawsBackground:NO];
      }
      [cell setObjectValue:AUTORELEASE([day copy])];
      if (_dataSource &&
	  [_dataSource respondsToSelector:@selector(visibleAppointmentsForDay:)] &&
	  [[_dataSource visibleAppointmentsForDay:day] count] > 0)
	[cell setFont:boldFont];
      else
	[cell setFont: normalFont];
      if ([day monthOfYear] == [monthDisplayed monthOfYear])
	[cell setTextColor:black];
      else
	[cell setTextColor:white];
    }
  }
  [self setSelectedDay];
  [day release];
}

- (void)dayChanged:(NSTimer *)timer
{
  [self updateView];
  if ([delegate respondsToSelector:@selector(calendarView:currentDateChanged:)])
    [delegate calendarView:self currentDateChanged:[Date today]];
}

- (void)previousYear:(id)sender
{
  Date *cdate = AUTORELEASE([date copy]);

  [cdate setYear:[cdate year]-1];
  [self setDate:cdate];
}
- (void)previousMonth:(id)sender
{
  Date *cdate = AUTORELEASE([monthDisplayed copy]);

  [cdate setMonth:[cdate monthOfYear]-1];
  [self setDate:cdate];
}
- (void)nextMonth:(id)sender
{
  Date *cdate = AUTORELEASE([monthDisplayed copy]);

  [cdate setMonth:[cdate monthOfYear]+1];
  [self setDate:cdate];
}
- (void)nextYear:(id)sender
{
  Date *cdate = AUTORELEASE([date copy]);

  [cdate setYear:[cdate year]+1];
  [self setDate:cdate];
}

- (void)selectDay:(id)sender
{
  id day = [[matrix selectedCell] objectValue];

  if ([day isKindOfClass:[Date class]]) {
    [self clearSelectedDay];
    ASSIGNCOPY(date, day);
    [self setSelectedDay];
    if ([delegate respondsToSelector:@selector(calendarView:selectedDateChanged:)])
      [delegate calendarView:self selectedDateChanged:date];
  }
}

- (void)doubleClick:(id)sender
{
  if ([[matrix selectedCell] tag] > 0 && [delegate respondsToSelector:@selector(calendarView:userActionForDate:)])
    [delegate calendarView:self userActionForDate:date];
}

- (void)setDelegate:(id)aDelegate
{
  ASSIGN(delegate, aDelegate);
}
- (id)delegate
{
  return delegate;
}

- (void)reloadData
{
  [self updateView];
}

- (id)dataSource
{
  return _dataSource;
}

- (void)setDataSource:(id)dataSource
{
  if (_dataSource == nil)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataChanged:) name:SADataChangedInStoreManager object:nil];
  ASSIGN(_dataSource, dataSource);
  [self updateView];
}

- (void)dataChanged:(NSNotification *)not
{
  [self updateView];
}

- (void)setDate:(Date *)nDate
{
  NSAssert([nDate isDate], @"Calendar expects a date");
  ASSIGNCOPY(date, nDate);
  ASSIGNCOPY(monthDisplayed, nDate);
  [self updateView];
  if ([delegate respondsToSelector:@selector(calendarView:selectedDateChanged:)])
    [delegate calendarView:self selectedDateChanged:date];
}
- (Date *)date
{
  return date;
}

- (NSString *)dateAsString
{
  return [[date calendarDate] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSDateFormatString]];
}
@end
