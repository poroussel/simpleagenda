/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "WeekView.h"
#import "ConfigManager.h"
#import "iCalTree.h"
#import "AppointmentView.h"
#import "SelectionManager.h"
#import "NSColor+SimpleAgenda.h"
#import "defines.h"

@interface AppWeekView : AppointmentView
{
}
@end

@implementation AppWeekView
#define TextRect(rect) NSMakeRect(rect.origin.x + 4, rect.origin.y, rect.size.width - 8, rect.size.height - 2)
#define CEC_BORDERSIZE 1
#define RADIUS 5
- (void)drawRect:(NSRect)rect
{
  NSPoint point;
  NSString *title;
  NSString *label;
  Date *start = [_apt startDate];
  NSColor *color = [[_apt store] eventColor];
  NSColor *darkColor = [color colorModifiedWithDeltaRed:-0.3 green:-0.3 blue:-0.3 alpha:-0.3];
  NSDictionary *textAttributes = [NSDictionary dictionaryWithObject:[[_apt store] textColor]
					                     forKey:NSForegroundColorAttributeName];

  if ([_apt allDay])
    title = [NSString stringWithFormat:_(@"All day : %@"), [_apt summary]];
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
  if ([[[SelectionManager globalManager] selection] containsObject:_apt])
    [[NSColor whiteColor] set];
  else
    [darkColor set];
  PSsetalpha(0.7);
  PSsetlinewidth(CEC_BORDERSIZE);
  PSstroke();
  [label drawInRect:TextRect(rect) withAttributes:textAttributes];
  point = NSMakePoint(rect.size.width - 18, rect.size.height - 16);
  if ([_apt rrule]) {
    [[self repeatImage] compositeToPoint:NSMakePoint(rect.size.width - 18, rect.size.height - 18) operation:NSCompositeSourceOver];
    point = NSMakePoint(rect.size.width - 30, rect.size.height - 16);
  }
  if ([_apt hasAlarms])
    [[self alarmImage] compositeToPoint:point operation:NSCompositeSourceOver];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  WeekView *parent = (WeekView *)[[self superview] superview];
  id delegate = [parent delegate];
   
  if ([theEvent clickCount] > 1) {
    if ([delegate respondsToSelector:@selector(viewEditEvent:)])
      [delegate viewEditEvent:_apt];
    return;
  }
  [self becomeFirstResponder];
  [parent selectAppointmentView:self];
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

  awv = [[AppWeekView alloc] initWithFrame:[self frameForNewAppointment:apt] appointment:apt];
  [awv setAutoresizingMask:NSViewWidthSizable];
  [self addSubview:AUTORELEASE(awv)];
}

- (Date *)day
{
  return date;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  WeekView *parent = (WeekView *)[self superview];
  id delegate = [parent delegate];

  if ([delegate respondsToSelector:@selector(viewSelectDate:)])
    [delegate viewSelectDate:date];
}
@end

@implementation WeekView
- (void)setupSelectWeek
{
  NSRect frame = [self frame];
  NSEnumerator *enumerator;
  NSView *view;
  int nday;
  Date *date;

  if ([_date weekOfYear] != weekNumber || [_date year] != year) {
    weekNumber = [_date weekOfYear];
    year = [_date year];
    enumerator = [[self subviews] objectEnumerator];
    while ((view = [enumerator nextObject]))
      [view removeFromSuperviewWithoutNeedingDisplay];
    /* Start with monday */
    date = [_date copy];
    [date changeDayBy: 1 - [date weekday]];
    for (nday = 0; nday < 7; nday++) {
      [self addSubview:AUTORELEASE([[WeekDayView alloc] initWithFrame:frame forDay:date])];
      [date incrementDay];
    }
    [date release];
  }
}

- (void)dealloc
{
  RELEASE(_date);
  [super dealloc];
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
  if ([delegate respondsToSelector:@selector(viewSelectDate:)])
    [delegate viewSelectDate:[(WeekDayView *)[aptv superview] day]];
  [[SelectionManager globalManager] select:[aptv appointment]];
  if ([delegate respondsToSelector:@selector(viewSelectEvent:)])
    [delegate viewSelectEvent:[aptv appointment]];
  [self setNeedsDisplay:YES];
}

- (void)reloadData
{
  NSEnumerator *enumerator, *enm;
  WeekDayView *wdv;
  Event *apt;
  NSSet *events;

  enumerator = [[self subviews] objectEnumerator];
  while ((wdv = [enumerator nextObject])) {
    [wdv clear];
    events = [[StoreManager globalManager] visibleAppointmentsForDay:[wdv day]];
    enm = [events objectEnumerator];
    while ((apt = [enm nextObject]))
      [wdv addAppointment:apt];
  }
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (void)config:(ConfigManager *)config dataDidChangedForKey:(NSString *)key
{
  [self reloadData];
}

- (void)setDate:(Date *)date
{
  ASSIGNCOPY(_date, date);
  [self setupSelectWeek];
  [self reloadData];
}
@end
