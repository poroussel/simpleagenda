/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "DayView.h"
#import "ConfigManager.h"
#import "defines.h"

#define max(x,y) ((x) > (y)) ? (x) : (y)
#define min(x,y) ((x) < (y)) ? (x) : (y)
#define abs(x) ((x) < 0) ? (-x) : (x)

#define RedimRect(frame) NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, 6)
#define TextRect(rect) NSMakeRect(rect.origin.x + 4, rect.origin.y, rect.size.width - 8, rect.size.height)

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
    ASSIGN(_apt, apt);
    _selected = NO;
    _textAttributes = [[NSDictionary dictionaryWithObject:[NSColor darkGrayColor]
				     forKey:NSForegroundColorAttributeName] retain];
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_apt);
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
  Date *start = [_apt startDate];
  NSColor *color = [[_apt store] eventColor];
  NSColor *darkColor = [NSColor colorWithCalibratedRed:[color redComponent] - 0.3
				green:[color greenComponent] - 0.3
				blue:[color blueComponent] - 0.3
				alpha:[color alphaComponent]];

  if ([_apt allDay])
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
  if (![_apt allDay])
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

- (NSDictionary *)defaults
{
  NSDictionary *dict = [NSDictionary 
			 dictionaryWithObjects:[NSArray arrayWithObjects:@"9", @"18", @"15", nil]
			 forKeys:[NSArray arrayWithObjects:FIRST_HOUR, LAST_HOUR, MIN_STEP, nil]];
  return dict;
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if (self) {
    ConfigManager *config = [ConfigManager globalConfig];
    [config registerDefaults:[self defaults]];
    [config registerClient:self forKey:FIRST_HOUR];
    [config registerClient:self forKey:LAST_HOUR];
    [config registerClient:self forKey:MIN_STEP];
    _firstH = [config integerForKey:FIRST_HOUR];
    _lastH = [config integerForKey:LAST_HOUR];
    _minStep = [config integerForKey:MIN_STEP];
    _textAttributes = [[NSDictionary dictionaryWithObject:[NSColor textColor]
 				     forKey:NSForegroundColorAttributeName] retain];
    _backgroundColor = [[[NSColor controlBackgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] retain];
    _alternateBackgroundColor = [[NSColor colorWithCalibratedRed:[_backgroundColor redComponent] + 0.05
					 green:[_backgroundColor greenComponent] + 0.05
					 blue:[_backgroundColor blueComponent] + 0.05
					 alpha:[_backgroundColor alphaComponent]] retain];
    [self reloadData];
  }
  return self;
}

- (void)dealloc
{
  [_backgroundColor release];
  [_alternateBackgroundColor release];
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

- (NSRect)_frameForAppointment:(Event *)apt
{
  int size, start;

  if ([apt allDay])
    return NSMakeRect(40, 0, _width - 48, _height);
  start = [self _minuteToPosition:[[apt startDate] minuteOfDay]];
  size = [self _minuteToSize:[apt duration]];
  return NSMakeRect(40, start - size, _width - 48, size);
}

- (int)_roundMinutes:(int)minutes
{
  return minutes / _minStep * _minStep;
}

- (void)drawRect:(NSRect)rect
{
  NSSize size;
  NSString *hour;
  AppointmentView *aptv; 
  NSEnumerator *enumerator;
  int h, start;
  int hrow;
  float miny, maxy;

  if (rect.origin.y == 0) {
    _height = rect.size.height;
    _width = rect.size.width;
  }
  /* 
   * FIXME : this is ugly and slow, we're doing
   * work when it's not needed and probably twice.
   */
  enumerator = [[self subviews] objectEnumerator];
  while ((aptv = [enumerator nextObject]))
    [aptv setFrame:[self _frameForAppointment:[aptv appointment]]];
  /*
   * FIXME : if we draw the string in the same
   * loop it doesn't appear on the screen.
   */
  hrow = [self _minuteToSize:60];
  for (h = _firstH; h <= _lastH + 1; h++) {
    start = [self _minuteToPosition:h * 60];
    if (h % 2)
      [_backgroundColor set];
    else
      [_alternateBackgroundColor set];
    NSRectFill(NSMakeRect(0, start, rect.size.width, hrow + 1));
  }
  for (h = _firstH; h <= _lastH; h++) {
    hour = [NSString stringWithFormat:@"%d h", h];
    start = [self _minuteToPosition:h * 60];
    size = [hour sizeWithAttributes:_textAttributes];
    [hour drawAtPoint:NSMakePoint(4, start - hrow / 2 - size.height / 2) withAttributes:_textAttributes];
  }
  if (_startPt.x != _endPt.x && _startPt.y != _endPt.y) {
    miny = min(_startPt.y, _endPt.y);
    maxy = max(_startPt.y, _endPt.y);
    [[NSColor grayColor] set];
    NSFrameRect(NSMakeRect(40, miny, rect.size.width - 48, maxy - miny));
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
  ConfigManager *config = [ConfigManager globalConfig];
  NSEnumerator *enumerator;
  AppointmentView *aptv;
  Event *apt;

  enumerator = [[self subviews] objectEnumerator];
  while ((aptv = [enumerator nextObject])) {
    [config unregisterClient:self forKey:[[[aptv appointment] store] description]];
    [aptv removeFromSuperview];
  }

  enumerator = [_dataSource scheduledAppointmentsForDayView];
  while ((apt = [enumerator nextObject])) {
    [config registerClient:self forKey:[[apt store] description]];
    if ([[apt store] displayed])
      [self addSubview:[[AppointmentView alloc] initWithFrame:[self _frameForAppointment:apt]
						appointment:apt]];
  }
  _selected = nil;
  [self setNeedsDisplay:YES];
}

- (void)_selectAppointmentView:(AppointmentView *)aptv
{
  if (_selected != aptv) {
    [_selected setSelected:NO];
    [aptv setSelected:YES];
    _selected = aptv;
    if ([delegate respondsToSelector:@selector(dayView:selectEvent:)])
      [delegate dayView:self selectEvent:[aptv appointment]];
  }
}

- (void)mouseDown:(NSEvent *)theEvent
{
  int start;
  int diff;
  int minutes;
  BOOL keepOn = YES;
  BOOL modified = NO;
  NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  NSView *hit = [self hitTest:mouseLoc];
  NSRect frame;
  BOOL inResize;

  [[self window] makeFirstResponder:self];
  if ([hit isKindOfClass:[AppointmentView class]]) {
    AppointmentView *aptv = hit;
    [self _selectAppointmentView:aptv];

    if ([theEvent clickCount] > 1) {
      if ([delegate respondsToSelector:@selector(doubleClickOnAppointment:)])
	[delegate doubleClickOnAppointment:[aptv appointment]];
      return;
    }

    if (![[[aptv appointment] store] isWritable])
      return;
    if ([[aptv appointment] allDay])
      return;

    frame = [aptv frame];
    inResize = [self mouse:mouseLoc inRect:RedimRect(frame)];
    if (inResize) {
      [[NSCursor resizeUpDownCursor] push];
      start = [[[aptv appointment] startDate] minuteOfDay];
      while (keepOn) {
	theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
	mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];

	switch ([theEvent type]) {
	case NSLeftMouseDragged:
	  minutes = [self _positionToMinute:mouseLoc.y];
	  [[aptv appointment] setDuration:[self _roundMinutes:minutes - start]];
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
    diff = [self _minuteToPosition:[[[aptv appointment] startDate] minuteOfDay]] - mouseLoc.y;
    while (keepOn) {
      theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
      mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
      switch ([theEvent type]) {
      case NSLeftMouseDragged:
	minutes = [self _positionToMinute:mouseLoc.y + diff];
	[[[aptv appointment] startDate] setMinute:[self _roundMinutes:minutes]];
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
  if (abs(_startPt.y - _endPt.y) > 7 && [self mouse:_endPt inRect:[self bounds]]) {
    int start = [self _positionToMinute:max(_startPt.y, _endPt.y)];
    int end = [self _positionToMinute:min(_startPt.y, _endPt.y)];
    if ([delegate respondsToSelector:@selector(createAppointmentFrom:to:)])
      [delegate createAppointmentFrom:[self _roundMinutes:start] to:[self _roundMinutes:end]];
  }
  _startPt = _endPt = NSMakePoint(0, 0);
  [self display];
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
    [[[_selected appointment] startDate] changeMinuteBy:-_minStep];
    [_selected setFrame:[self _frameForAppointment:[_selected appointment]]];
    [delegate modifyAppointment:[_selected appointment]];
    [self display];
  }
}

- (void)moveDown:(id)sender
{
  if (_selected != nil) {
    [[[_selected appointment] startDate] changeMinuteBy:_minStep];
    [_selected setFrame:[self _frameForAppointment:[_selected appointment]]];
    [delegate modifyAppointment:[_selected appointment]];
    [self display];
  }
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (void)config:(ConfigManager*)config dataDidChangedForKey:(NSString *)key
{
  _firstH = [config integerForKey:FIRST_HOUR];
  _lastH = [config integerForKey:LAST_HOUR];
  _minStep = [config integerForKey:MIN_STEP];
  [self reloadData];
}

- (int)firstHour
{
  return _firstH;
}

- (int)lastHour
{
  return _lastH;
}

- (int)minimumStep
{
  return _minStep;
}

@end

