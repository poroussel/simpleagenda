/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "WeekView.h"
#import "ConfigManager.h"
#import "iCalTree.h"
#import "AppointmentView.h"
#import "defines.h"


@interface AppWeekView : AppointmentView
{
}
@end

@implementation AppWeekView
@end

@implementation WeekView
- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if (self) {
    [self reloadData];
  }
  return self;
}

- (void)dealloc
{
  [super dealloc];
}

- (NSRect)frameForAppointment:(Event *)apt
{
}
- (void)drawRect:(NSRect)rect
{
  NSString *sdate;
  Date *selectedDate;
  Date *date;
  int weekNumber;
  NSSize size;
  int dwidth = rect.size.width / 2;
  int dheight = rect.size.height / 3;

  selectedDate = [dataSource selectedDate];
  weekNumber = [selectedDate weekOfYear];

  /* Select monday */
  date = [selectedDate copy];
  [date changeDayBy: 1 - [selectedDate weekday]];

  [[NSColor grayColor] set];
  NSFrameRect(NSMakeRect(dwidth - 1, 0, 1, dheight * 3));
  NSFrameRect(NSMakeRect(dwidth * 2 - 1, 0, 1, dheight * 3));

  NSFrameRect(NSMakeRect(0, dheight * 3 - 1, dwidth * 2, 1));
  NSFrameRect(NSMakeRect(dwidth / 4, dheight * 3 - 17, dwidth * 3 / 4, 1));
  NSFrameRect(NSMakeRect(dwidth + dwidth / 4, dheight * 3 - 17, dwidth * 3 / 4, 1));

  NSFrameRect(NSMakeRect(0, dheight * 2, dwidth * 2, 1));
  NSFrameRect(NSMakeRect(dwidth / 4, dheight * 2 - 17, dwidth * 3 / 4, 1));
  NSFrameRect(NSMakeRect(dwidth + dwidth / 4, dheight * 2 - 17, dwidth * 3 / 4, 1));

  NSFrameRect(NSMakeRect(0, dheight, dwidth * 2, 1));
  NSFrameRect(NSMakeRect(dwidth / 4, dheight - 17, dwidth * 3 / 4, 1));
  NSFrameRect(NSMakeRect(dwidth + dwidth / 4, dheight - 17, dwidth * 3 / 4, 1));

  sdate = [[date calendarDate] descriptionWithCalendarFormat:@"%A %d %B"];
  size = [sdate sizeWithAttributes:nil];
  [sdate drawInRect:NSMakeRect(dwidth - size.width - 4, dheight * 3 - 15, size.width, 14) withAttributes:nil];

  [date changeDayBy: 1];
  sdate = [[date calendarDate] descriptionWithCalendarFormat:@"%A %d %B"];
  size = [sdate sizeWithAttributes:nil];
  [sdate drawInRect:NSMakeRect(dwidth - size.width - 4, dheight * 2 - 15, size.width, 14) withAttributes:nil];

  [date changeDayBy: 1];
  sdate = [[date calendarDate] descriptionWithCalendarFormat:@"%A %d %B"];
  size = [sdate sizeWithAttributes:nil];
  [sdate drawInRect:NSMakeRect(dwidth - size.width - 4, dheight - 15, size.width, 14) withAttributes:nil];

  [date changeDayBy: 1];
  sdate = [[date calendarDate] descriptionWithCalendarFormat:@"%A %d %B"];
  size = [sdate sizeWithAttributes:nil];
  [sdate drawInRect:NSMakeRect(dwidth * 2 - size.width - 4, dheight * 3 - 16, size.width, 14) withAttributes:nil];

  [date changeDayBy: 1];
  sdate = [[date calendarDate] descriptionWithCalendarFormat:@"%A %d %B"];
  size = [sdate sizeWithAttributes:nil];
  [sdate drawInRect:NSMakeRect(dwidth * 2 - size.width - 4, dheight * 2 - 16, size.width, 14) withAttributes:nil];
}

- (id)dataSource
{
  return dataSource;
}
- (void)setDataSource:(id)source
{
  dataSource = source;
}
- (id)delegate
{
  return delegate;
}
- (void)setDelegate:(id)theDelegate
{
  delegate = theDelegate;
}

- (void)selectAppointmentView:(AppointmentView *)aptv
{
}

- (void)reloadData
{
  [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (void)config:(ConfigManager*)config dataDidChangedForKey:(NSString *)key
{
  [self reloadData];
}

- (void)deselectAll:(id)sender
{
  if (_selected) {
    [_selected setSelected:NO];
    [self setNeedsDisplay:YES];
    _selected = nil;
  }
}
@end
