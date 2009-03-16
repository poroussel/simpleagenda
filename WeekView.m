/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "WeekView.h"
#import "ConfigManager.h"
#import "iCalTree.h"
#import "AppointmentView.h"
#import "NSColor+SimpleAgenda.h"
#import "defines.h"

@interface AppWeekView : AppointmentView
{
  BOOL _selected;
}
@end

@implementation AppWeekView
#define TextRect(rect) NSMakeRect(rect.origin.x + 4, rect.origin.y, rect.size.width - 8, rect.size.height - 2)
#define CEC_BORDERSIZE 1
#define RADIUS 5
- (void)drawRect:(NSRect)rect
{
  NSString *title;
  NSString *label;
  Date *start = [_apt startDate];
  NSColor *color = [[_apt store] eventColor];
  NSColor *darkColor = [color colorModifiedWithDeltaRed:-0.3 green:-0.3 blue:-0.3 alpha:-0.3];
  NSDictionary *textAttributes = [NSDictionary dictionaryWithObject:[[_apt store] textColor]
					                     forKey:NSForegroundColorAttributeName];

  if ([_apt allDay])
    title = [NSString stringWithFormat:@"All day : %@", [_apt summary]];
  else
    title = [NSString stringWithFormat:@"%2dh%0.2d : %@", [start hourOfDay], [start minuteOfHour], [_apt summary]];
  if ([_apt text])
    label = [NSString stringWithFormat:@"%@\n\n%@", title, [[_apt text] string]];
  else
    label = [NSString stringWithString:title];

  PSnewpath();
  PSmoveto(RADIUS + CEC_BORDERSIZE, CEC_BORDERSIZE);
  PSrcurveto(-RADIUS, 0, -RADIUS, RADIUS, -RADIUS, RADIUS);
  PSrlineto(0, NSHeight(rect) + rect.origin.y - 2 * (RADIUS + CEC_BORDERSIZE));
  PSrcurveto( 0, RADIUS, RADIUS, RADIUS, RADIUS, RADIUS);
  PSrlineto(NSWidth(rect) - 2 * (RADIUS + CEC_BORDERSIZE),0);
  PSrcurveto( RADIUS, 0, RADIUS, -RADIUS, RADIUS, -RADIUS);
  PSrlineto(0, -NSHeight(rect) - rect.origin.y + 2 * (RADIUS + CEC_BORDERSIZE));
  PSrcurveto(0, -RADIUS, -RADIUS, -RADIUS, -RADIUS, -RADIUS);
  PSclosepath();
  PSgsave();
  [color set];
  PSsetalpha(0.7);
  PSfill();
  PSgrestore();
  if (_selected)
    [[NSColor whiteColor] set];
  else
    [darkColor set];
  PSsetalpha(0.7);
  PSsetlinewidth(CEC_BORDERSIZE);
  PSstroke();
  [label drawInRect:TextRect(rect) withAttributes:textAttributes];
  if ([_apt rrule] != nil)
    [[self repeatImage] compositeToPoint:NSMakePoint(rect.size.width - 18, rect.size.height - 18) operation:NSCompositeSourceOver];
}
@end

static struct {
  float mx;
  float my;
  float sx;
  float sy;
} wdcoord[7] = {{0, 2, 1, 1}, {0, 1, 1, 1}, {0, 0, 1, 1}, {1, 2, 1, 1}, {1, 1, 1, 1}, {1, 0.5, 1, 0.5}, {1, 0, 1, 0.5}};

@interface WeekDayView : NSView
{
  Date *date;
}
- (id)initWithFrame:(NSRect)frame forDay:(Date *)day;
- (void)clear;
- (void)addAppointment:(Event *)apt;
- (Date *)day;
@end

@implementation WeekDayView
+ (NSRect)rectForDay:(int)weekday frame:(NSRect)frame
{
  int dwidth = frame.size.width / 2;
  int dheight = frame.size.height / 3;
  return NSMakeRect(dwidth * wdcoord[weekday - 1].mx, dheight * wdcoord[weekday - 1].my, dwidth * wdcoord[weekday - 1].sx, dheight * wdcoord[weekday - 1].sy);
}

- (id)initWithFrame:(NSRect)frame forDay:(Date *)day
{
  self = [super initWithFrame:[WeekDayView rectForDay:[day weekday] frame:frame]];
  if (self)
    date = [day copy];
  return self;
}

- (void)dealloc
{
  [date release];
  [super dealloc];
}

- (void)drawRect:(NSRect)rect
{
  int dwidth = rect.size.width;
  int dheight = rect.size.height;
  NSString *sdate;
  NSSize size;

  [[NSColor grayColor] set];
  NSFrameRect(NSMakeRect(4, dheight - 5, dwidth, 1));
  NSFrameRect(NSMakeRect(dwidth / 4, dheight - 17, dwidth * 3 / 4, 1));
  NSFrameRect(NSMakeRect(dwidth - 1, 0, 1, dheight));
  sdate = [[date calendarDate] descriptionWithCalendarFormat:@"%A %d %B"];
  size = [sdate sizeWithAttributes:nil];
  [sdate drawInRect:NSMakeRect(dwidth - size.width - 4, dheight - 17, size.width, 14) withAttributes:nil];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
  [self setFrame:[WeekDayView rectForDay:[date weekday] frame:[[self superview] frame]]];
}

- (void)clear
{
  NSEnumerator *enumerator;
  NSView *view;

  enumerator = [[self subviews] objectEnumerator];
  while ((view = [enumerator nextObject]))
    [view removeFromSuperviewWithoutNeedingDisplay];
}

- (NSRect)frameForNewAppointment:(Event *)apt
{
  return NSMakeRect(0, 0 + 20 * [[self subviews] count] , [self frame].size.width, 20);
}

- (void)addAppointment:(Event *)apt
{
  AppWeekView *awv;

  awv = AUTORELEASE([[AppWeekView alloc] initWithFrame:[self frameForNewAppointment:apt] appointment:apt]);
  [awv setAutoresizingMask:NSViewWidthSizable];
  [self addSubview:awv];
}

- (Date *)day
{
  return date;
}
@end

@implementation WeekView
- (void)setDate:(Date *)aDate
{
  NSRect frame = [self frame];
  NSEnumerator *enumerator;
  NSView *view;
  int nday;
  Date *date;

  if ([aDate weekOfYear] != weekNumber) {
    weekNumber = [aDate weekOfYear];
    enumerator = [[self subviews] objectEnumerator];
    while ((view = [enumerator nextObject]))
      [view removeFromSuperviewWithoutNeedingDisplay];
    /* Start with monday */
    date = [aDate copy];
    [date changeDayBy: 1 - [date weekday]];
    for (nday = 0; nday < 7; nday++) {
      [self addSubview:AUTORELEASE([[WeekDayView alloc] initWithFrame:frame forDay:date])];
      [date incrementDay];
    }
    [date release];
  }
}
- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if (self)
    [self setDate:[Date today]];
  return self;
}

- (void)dealloc
{
  [super dealloc];
}

- (id)dataSource
{
  return dataSource;
}
- (void)setDataSource:(id)source
{
  dataSource = source;
  [self reloadData];
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
  NSEnumerator *enumerator, *enm;
  WeekDayView *wdv;
  Event *apt;
  NSSet *events;

  [self setDate:[dataSource selectedDate]];
  enumerator = [[self subviews] objectEnumerator];
  while ((wdv = [enumerator nextObject])) {
    [wdv clear];
    events = [dataSource scheduledAppointmentsForDay:[wdv day]];
    enm = [events objectEnumerator];
    while ((apt = [enm nextObject]))
      [wdv addAppointment:apt];
  }
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (void)config:(ConfigManager*)config dataDidChangedForKey:(NSString *)key
{
  [self reloadData];
}
@end
