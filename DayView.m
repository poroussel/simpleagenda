/* emacs buffer mode hint -*- objc -*- */

#import <ChronographerSource/Date.h>
#import <ChronographerSource/Appointment.h>
#import "DayView.h"

#define max(x,y) (x > y) ? x : y
#define min(x,y) (x < y) ? x : y

@interface AppointmentView : NSView
{
  Appointment *_apt;
  NSDictionary *_textAttributes;
  NSColor *_yellow;
  NSColor *_darkYellow;
  BOOL _selected;
}

- (Appointment *)appointment;

@end

@implementation AppointmentView

- (id)initWithFrame:(NSRect)frameRect appointment:(Appointment *)apt;
{
  self = [super initWithFrame:frameRect];
  if (self) {
    _apt = apt;
    _selected = NO;
    _textAttributes = RETAIN([NSDictionary dictionaryWithObject:[NSColor darkGrayColor]
					   forKey:NSForegroundColorAttributeName]);
    _yellow = [[NSColor yellowColor] copy];
    _darkYellow = RETAIN([NSColor colorWithCalibratedRed:[_yellow redComponent] - 0.3
				  green:[_yellow greenComponent] - 0.3
				  blue:[_yellow blueComponent] - 0.3
				  alpha:[_yellow alphaComponent]]);
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_textAttributes);
  RELEASE(_yellow);
  RELEASE(_darkYellow);
  [super dealloc];
}

- (BOOL)selected
{
  return _selected;
}

- (void)setSelected:(BOOL)selected
{
  if (selected != _selected) {
    _selected = selected;
    [self display];
  }
}

- (void)drawRect:(NSRect)rect
{
  NSCalendarDate *start = [[_apt startDate] calendarDate];
  NSString *label = [NSString stringWithFormat:@"%2dh%0.2d : %@",
			      [start hourOfDay],
			      [start minuteOfHour],
			      [_apt title]];
  [_darkYellow set];
  NSFrameRect(rect);
  [_yellow set];
  NSRectFill(NSMakeRect(rect.origin.x, rect.origin.y + 1, rect.size.width - 1, rect.size.height));
  [label drawInRect:NSMakeRect(4, 4, rect.size.width - 8, rect.size.height - 8) withAttributes:_textAttributes];
  if (_selected) {
    [[NSColor darkGrayColor] set];
    NSFrameRect(rect);
  }
}

- (Appointment *)appointment
{
  return _apt;
}

- (int)_deltaToMinute:(float)delta
{
  return [_apt duration] * delta / [self frame].size.height;
}

@end


@implementation DayView

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if (self) {
    NSLog(@"DayView initWithFrame");
    _height = frameRect.size.height;
    _width = frameRect.size.width;
    _textAttributes = RETAIN([NSDictionary dictionaryWithObject:[NSColor darkGrayColor]
					   forKey:NSForegroundColorAttributeName]);
    [self reloadData];
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_textAttributes);
  [super dealloc];
}

- (int)_minuteToSize:(int)minutes
{
  return minutes * _height / ((_lastH - _firstH + 1) * 60);
}

- (int)_minuteToPosition:(int)minutes
{
  return _height - [self _minuteToSize:minutes - (_firstH * 60)] - 1;
}

- (NSRect)_frameForAppointment:(Appointment *)apt
{
  int size, start;
  
  start = [self _minuteToPosition:[[apt startDate] minuteOfDay]];
  size = [self _minuteToSize:[apt duration]];
  return NSMakeRect(48, start - size, 180, size);
}

- (void)drawRect:(NSRect)rect
{
  int h, start;

  [[NSColor controlBackgroundColor] set];
  NSFrameRect(rect);

  for (h = _firstH; h <= _lastH; h++) {
    NSString *hour = [NSString stringWithFormat:@"%d h", h];
    start = [self _minuteToPosition:h * 60];
    [[NSColor grayColor] set];
    NSFrameRect(NSMakeRect(0, start, rect.size.width, 1));
    [hour drawInRect:NSMakeRect(4, start - 20, 80, 16) withAttributes:_textAttributes];
  }
  if (_startPt.x != _endPt.x && _startPt.y != _endPt.y) {
    float minx, miny, maxx, maxy;

    minx = min(_startPt.x, _endPt.x);
    miny = min(_startPt.y, _endPt.y);
    maxx = max(_startPt.x, _endPt.x);
    maxy = max(_startPt.y, _endPt.y);
    NSFrameRect(NSMakeRect(minx, miny, maxx - minx, maxy - miny));
  }
}

- (id)dataSource
{
  return _dataSource;
}

- (void)setDataSource:(id)source
{
  _dataSource = source;
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

- (void)reloadData
{
  NSEnumerator *enumerator;
  AppointmentView *aptv;
  Appointment *apt;

  _firstH = [_dataSource firstHourForDayView];
  _lastH = [_dataSource lastHourForDayView];

  enumerator = [[self subviews] objectEnumerator];
  while ((aptv = [enumerator nextObject]))
    [aptv removeFromSuperview];

  enumerator = [_dataSource scheduledAppointmentsForDayView];
  while ((apt = [enumerator nextObject]))
    [self addSubview:[[AppointmentView alloc] initWithFrame:[self _frameForAppointment:apt]
					      appointment:apt]];
  _selected = nil;
  [self setNeedsDisplay:YES];
}

- (void)_selectAppointmentView:(AppointmentView *)aptv
{
  [_selected setSelected:NO];
  [aptv setSelected:YES];
  _selected = aptv;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  int minutes;
  BOOL keepOn = YES;
  BOOL modified = NO;
  NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  NSView *hit = [self hitTest:mouseLoc];

  if ([hit class] == [AppointmentView class]) {
    AppointmentView *aptv = hit;
    if ([theEvent clickCount] > 1) {
      if ([delegate respondsToSelector:@selector(doubleClickOnAppointment:)])
	[delegate doubleClickOnAppointment:[aptv appointment]];
      return;
    }
    [self _selectAppointmentView:aptv];
    while (keepOn) {
      theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
      mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];

      switch ([theEvent type]) {
      case NSLeftMouseDragged:
	minutes = [aptv _deltaToMinute:[theEvent deltaY]];
	[[[aptv appointment] startDate] changeMinuteBy:-minutes];
	[aptv setFrame:[self _frameForAppointment:[aptv appointment]]];
	modified = YES;
	[self display];
	break;
      case NSLeftMouseUp:
	keepOn = NO;
	break;
      default:
	break;
      }
    }
    if (modified && [delegate respondsToSelector:@selector(modifyAppointment:)])
      [delegate modifyAppointment:[aptv appointment]];
    return;
  }

  _startPt = mouseLoc;
  while (keepOn) {
    theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
    _endPt = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    switch ([theEvent type]) {
    case NSLeftMouseUp:
      keepOn = NO;
      break;
    default:
      break;
    }
    [self display];
  }
  _startPt = _endPt = NSMakePoint(0, 0);
  [self display];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  NSView *hit = [self hitTest:[self convertPoint:[theEvent locationInWindow] fromView:nil]];

  if ([hit class] == [AppointmentView class])
    [self _selectAppointmentView:(AppointmentView *)hit];
  return nil;
}

- (Appointment *)selectedAppointment
{
  return [_selected appointment];
}

@end
