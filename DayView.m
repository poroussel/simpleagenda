/* emacs buffer mode hint -*- objc -*- */

#import <ChronographerSource/Date.h>
#import <ChronographerSource/Appointment.h>
#import "DayView.h"

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
  [label drawAtPoint:NSMakePoint(16, rect.size.height - 24) withAttributes:_textAttributes];
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
  _firstH = [_dataSource firstHour];
  _lastH = [_dataSource lastHour];

  [[NSColor controlBackgroundColor] set];
  NSFrameRect(rect);

  for (h = _firstH; h <= _lastH; h++) {
    NSString *hour = [NSString stringWithFormat:@"%d h", h];
    start = [self _minuteToPosition:h * 60];
    [[NSColor grayColor] set];
    NSFrameRect(NSMakeRect(0, start, rect.size.width, 1));
    [hour drawInRect:NSMakeRect(4, start - 20, 80, 16) withAttributes:_textAttributes];
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

  enumerator = [[self subviews] objectEnumerator];
  while ((aptv = [enumerator nextObject]))
    [aptv removeFromSuperview];

  enumerator = [_dataSource scheduledAppointments];
  while ((apt = [enumerator nextObject]))
    [self addSubview:[[AppointmentView alloc] initWithFrame:[self _frameForAppointment:apt]
					      appointment:apt]];
  [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  int minutes;
  BOOL keepOn = YES;
  BOOL isInside = YES;
  NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  NSView *hit = [self hitTest:mouseLoc];

  if ([hit class] == [AppointmentView class]) {
    AppointmentView *aptv = hit;
    if ([theEvent clickCount] > 1) {
      if ([delegate respondsToSelector:@selector(actionForAppointment:)])
	[delegate actionForAppointment:[aptv appointment]];
      return;
    }
    [aptv setSelected:YES];
    while (keepOn) {
      theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
      mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];

      switch ([theEvent type]) {
      case NSLeftMouseDragged:
	  minutes = [aptv _deltaToMinute:[theEvent deltaY]];
	  [[[aptv appointment] startDate] changeMinuteBy:-minutes];
	  [aptv setFrame:[self _frameForAppointment:[aptv appointment]]];
	  [self display];
	break;
      case NSLeftMouseUp:
	[aptv setSelected:NO];
	keepOn = NO;
	break;
      default:
	break;
      }
    }
    return;
  }

  NSPoint start = mouseLoc;
  while (keepOn) {
    theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask |
			      NSLeftMouseDraggedMask];
    mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    isInside = [self mouse:mouseLoc inRect:[self bounds]];

    switch ([theEvent type]) {
    case NSLeftMouseDragged:
      if (isInside) {
	NSRectFill(NSMakeRect(start.x, start.y, mouseLoc.x - start.x, start.y - mouseLoc.y));
      }
      break;
    case NSLeftMouseUp:
      NSRectFill(NSMakeRect(start.x, start.y, mouseLoc.x - start.x, start.y - mouseLoc.y));
      keepOn = NO;
      break;
    default:
      break;
    }
  }
}

- (Appointment *)selectedAppointment
{
  return nil;
}

@end
