/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "DayView.h"

#define max(x,y) ((x) > (y)) ? (x) : (y)
#define min(x,y) ((x) < (y)) ? (x) : (y)
#define abs(x) ((x) < 0) ? (-x) : (x)

#define RedimRect(frame) NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, 6)
#define TextRect(rect) NSMakeRect(rect.origin.x + 4, rect.origin.y + 4, rect.size.width - 8, rect.size.height - 8)

@interface AppointmentView : NSView
{
  Event *_apt;
  NSDictionary *_textAttributes;
  BOOL _selected;
}

- (Event *)appointment;

@end

@implementation AppointmentView

- (id)initWithFrame:(NSRect)frameRect appointment:(Event *)apt;
{
  self = [super initWithFrame:frameRect];
  if (self) {
    _apt = apt;
    _selected = NO;
    _textAttributes = [[NSDictionary dictionaryWithObject:[NSColor darkGrayColor]
				     forKey:NSForegroundColorAttributeName] retain];
  }
  return self;
}

- (void)dealloc
{
  [_textAttributes release];
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
  NSString *title;
  NSString *label;
  NSCalendarDate *start = [[_apt startDate] calendarDate];
  NSColor *color = [[_apt store] eventColor];
  NSColor *darkColor = [NSColor colorWithCalibratedRed:[color redComponent] - 0.3
				green:[color greenComponent] - 0.3
				blue:[color blueComponent] - 0.3
				alpha:[color alphaComponent]];

  if ([_apt duration] == 1440)
    title = [NSString stringWithFormat:@"All day : %@", [_apt title]];
  else
    title = [NSString stringWithFormat:@"%2dh%0.2d : %@", [start hourOfDay], [start minuteOfHour], [_apt title]];
  if ([_apt descriptionText])
    label = [NSString stringWithFormat:@"%@\n\n%@", title, [[_apt descriptionText] string]];
  else
    label = [NSString stringWithString:title];

  [color set];
  NSRectFill(rect);
  [darkColor set];
  NSRectFill(RedimRect(rect));
  [label drawInRect:TextRect(rect) withAttributes:_textAttributes];
  if (_selected) {
    [[NSColor grayColor] set];
    NSFrameRect(rect);
  }
}

- (Event *)appointment
{
  return _apt;
}

@end


@implementation DayView

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if (self) {
    _height = frameRect.size.height;
    _width = frameRect.size.width;
    _textAttributes = [[NSDictionary dictionaryWithObject:[NSColor darkGrayColor]
				     forKey:NSForegroundColorAttributeName] retain];
    [self reloadData];
  }
  return self;
}

- (void)dealloc
{
  [_textAttributes release];
  [super dealloc];
}

/* FIXME : the following could probably be simplified... */
- (int)_minuteToSize:(int)minutes
{
  return minutes * _height / ((_lastH - _firstH + 1) * 60);
}

- (int)_minuteToPosition:(int)minutes
{
  return _height - [self _minuteToSize:minutes - (_firstH * 60)] - 1;
}

- (int)_positionToMinute:(float)position
{
  return ((_lastH + 1) * 60) - ((_lastH - _firstH + 1) * 60) * position / _height;
}

- (int)_deltaToMinute:(float)delta
{
  return ((_lastH - _firstH + 1) * 60) * delta / _height;
}

- (NSRect)_frameForAppointment:(Event *)apt
{
  int size, start;
  
  start = [self _minuteToPosition:[[apt startDate] minuteOfDay]];
  size = [self _minuteToSize:[apt duration]];
  return NSMakeRect(40, start - size, [self frame].size.width - 56, size);
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
    float miny, maxy;

    miny = min(_startPt.y, _endPt.y);
    maxy = max(_startPt.y, _endPt.y);
    [[NSColor grayColor] set];
    NSFrameRect(NSMakeRect(40, miny, rect.size.width - 56, maxy - miny));
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
  Event *apt;

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
  NSRect frame;
  BOOL inResize;

  [[self window] makeFirstResponder:self];
  if ([hit class] == [AppointmentView class]) {
    AppointmentView *aptv = hit;
    [self _selectAppointmentView:aptv];

    if ([theEvent clickCount] > 1) {
      if ([delegate respondsToSelector:@selector(doubleClickOnAppointment:)])
	[delegate doubleClickOnAppointment:[aptv appointment]];
      return;
    }

    if (![[[aptv appointment] store] isWritable])
      return;

    frame = [aptv frame];
    inResize = [self mouse:mouseLoc inRect:RedimRect(frame)];
    if (inResize) {
      [[NSCursor resizeUpDownCursor] push];
      while (keepOn) {
	theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
	mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];

	switch ([theEvent type]) {
	case NSLeftMouseDragged:
	  minutes = [self _deltaToMinute:[theEvent deltaY]];
	  [[aptv appointment] setDuration:[[aptv appointment] duration] - minutes];
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
      [NSCursor pop];
      if (modified && [delegate respondsToSelector:@selector(modifyAppointment:)])
	[delegate modifyAppointment:[aptv appointment]];
      return;
    }

    [[NSCursor openHandCursor] push];
    while (keepOn) {
      theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
      mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];

      switch ([theEvent type]) {
      case NSLeftMouseDragged:
	minutes = [self _deltaToMinute:[theEvent deltaY]];
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
    [NSCursor pop];
    if (modified && [delegate respondsToSelector:@selector(modifyAppointment:)])
      [delegate modifyAppointment:[aptv appointment]];
    return;
  }

  _startPt = _endPt = mouseLoc;
  [[NSCursor crosshairCursor] push];
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
  [NSCursor pop];
  /* If pointer is inside DayView, create a new appointment */
  if (abs(_startPt.y - _endPt.y) > 7 && [self mouse:_endPt inRect:[self bounds]]) {
    int start = [self _positionToMinute:max(_startPt.y, _endPt.y)];
    int end = [self _positionToMinute:min(_startPt.y, _endPt.y)];
    if ([delegate respondsToSelector:@selector(createAppointmentFrom:to:)])
      [delegate createAppointmentFrom:start to:end];
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

- (Event *)selectedAppointment
{
  return [_selected appointment];
}

- (void)keyDown:(NSEvent *)theEvent
{
    [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void)moveUp:(id)sender
{
  if (_selected != nil) {
    [[[_selected appointment] startDate] changeMinuteBy:-[_dataSource minimumStepForDayView]];
    [_selected setFrame:[self _frameForAppointment:[_selected appointment]]];
    [delegate modifyAppointment:[_selected appointment]];
    [self display];
  }
}

- (void)moveDown:(id)sender
{
  if (_selected != nil) {
    [[[_selected appointment] startDate] changeMinuteBy:[_dataSource minimumStepForDayView]];
    [_selected setFrame:[self _frameForAppointment:[_selected appointment]]];
    [delegate modifyAppointment:[_selected appointment]];
    [self display];
  }
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

@end

