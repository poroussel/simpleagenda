/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "AgendaStore.h"
#import "DayView.h"
#import "ConfigManager.h"
#import "iCalTree.h"
#import "AppointmentView.h"
#import "SelectionManager.h"
#import "NSColor+SimpleAgenda.h"
#import "defines.h"

#define RedimRect(frame) NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, 10)
#define TextRect(rect) NSMakeRect(rect.origin.x + 4, rect.origin.y, rect.size.width - 8, rect.size.height - 2)

@interface DayView(Private)
- (NSRect)frameForAppointment:(Event *)apt;
- (int)minuteToPosition:(int)minutes;
- (int)positionToMinute:(float)position;
- (int)roundMinutes:(int)minutes;
- (int)distanceToDuration:(int)distance;
@end

@interface AppDayView : AppointmentView
{
}
@end

@implementation AppDayView
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
  if (![_apt allDay] && ![_apt sticky]) {
    NSRect rd = RedimRect(rect);
    PSnewpath();
    PSmoveto(RADIUS + CEC_BORDERSIZE, rd.origin.y);
    PSrcurveto( -RADIUS, 0, -RADIUS, RADIUS, -RADIUS, RADIUS);
    PSrlineto(0,NSHeight(rd) - 2 * (RADIUS + CEC_BORDERSIZE));
    PSrcurveto( 0, RADIUS, RADIUS, RADIUS, RADIUS, RADIUS);
    PSrlineto(NSWidth(rd) - 2 * (RADIUS + CEC_BORDERSIZE),0);
    PSrcurveto( RADIUS, 0, RADIUS, -RADIUS, RADIUS, -RADIUS);
    PSrlineto(0, -NSHeight(rd) + 2 * (RADIUS + CEC_BORDERSIZE));
    PSrcurveto( 0, -RADIUS, -RADIUS, -RADIUS, -RADIUS, -RADIUS);
    PSclosepath();
    [darkColor set];
    PSsetalpha(0.7);
    PSfill();
  }
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
  DayView *parent = (DayView *)[self superview];
  id delegate = [parent delegate];
  NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  int minutes;
  BOOL keepOn = YES;
  BOOL modified = NO;
  BOOL inResize;

  if ([theEvent clickCount] > 1) {
    if ([delegate respondsToSelector:@selector(viewEditEvent:)])
      [delegate viewEditEvent:_apt];
    return;
  }
  [self becomeFirstResponder];
  [parent selectAppointmentView:self];

  if (![[_apt store] writable] || [_apt allDay] || [_apt sticky])
    return;
  inResize = [self mouse:mouseLoc inRect:RedimRect([self bounds])];
  if (inResize) {
    int startduration = [_apt duration];
    int starty = [self convertPoint:[theEvent locationInWindow] fromView:self].y;
    int minStep = [parent minimumStep];
    int diffduration;
    int newy;

    [[NSCursor resizeUpDownCursor] push];
    while (keepOn) {
      theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
      newy = [self convertPoint:[theEvent locationInWindow] fromView:self].y;

      switch ([theEvent type]) {
      case NSLeftMouseDragged:
	diffduration = [parent distanceToDuration:starty-newy];
	minutes = [parent roundMinutes:startduration+diffduration];
	if (minutes < minStep)
	  minutes = minStep;
	if (minutes != [_apt duration]) {
	  [_apt setDuration:minutes];
	  modified = YES;
	  [self setFrame:[parent frameForAppointment:_apt]];
	  [parent setNeedsDisplay:YES];
	}
	break;
      case NSLeftMouseUp:
	keepOn = NO;
	break;
      default:
	break;
      }
    }
  } else {
    int startM, currentM, roundedDiffM;
    Date *date = [[_apt startDate] copy];

    [[NSCursor openHandCursor] push];
    startM = [parent positionToMinute:[theEvent locationInWindow].y];
    while (keepOn) {
      theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
      switch ([theEvent type]) {
      case NSLeftMouseDragged:
	currentM = [parent positionToMinute:[theEvent locationInWindow].y];
	roundedDiffM = [parent roundMinutes:currentM-startM];
	if (roundedDiffM != 0) {
	  modified = YES;
	  [_apt setStartDate:[Date dateWithTimeInterval:roundedDiffM*60 sinceDate:date]];
	  [self setFrame:[parent frameForAppointment:_apt]];
	  [parent setNeedsDisplay:YES];
	}
	break;
      case NSLeftMouseUp:
	keepOn = NO;
	break;
      default:
	break;
      }
    }
    [date release];
  }
  [NSCursor pop];
  if (modified && [delegate respondsToSelector:@selector(viewModifyEvent:)])
    [delegate viewModifyEvent:_apt];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
  DayView *parent = (DayView *)[self superview];
  [self setFrame:[parent frameForAppointment:_apt]];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
  NSMenu *menu;
  id <NSMenuItem> item;

  if ((menu = [super menuForEvent:event])) {
    item = [menu insertItemWithTitle:[_apt sticky] ? _(@"Unset sticky") : _(@"Set sticky")
			      action:@selector(changeSticky:)
		       keyEquivalent:nil
			     atIndex:1];
    [item setTarget:self];
  }
  return menu;
}
@end

NSComparisonResult compareAppointmentViews(id a, id b, void *data)
{
  return [[[a appointment] startDate] compare:[[b appointment] startDate] withTime:YES];
}

@implementation DayView
- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"9", @"18", @"15", nil]
		       forKeys:[NSArray arrayWithObjects:FIRST_HOUR, LAST_HOUR, MIN_STEP, nil]];
}


- (void)colorsDidChanged:(NSNotification *)not
{
  DESTROY(_backgroundColor);
  DESTROY(_alternateBackgroundColor);
  _backgroundColor = [[[NSColor controlBackgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] retain];
  _alternateBackgroundColor = [[_backgroundColor colorModifiedWithDeltaRed:0.05 green:0.05 blue:0.05 alpha:0] retain];
  [self setNeedsDisplay:YES];
}

- (id)initWithFrame:(NSRect)frameRect
{
  if ((self = [super initWithFrame:frameRect])) {
    ConfigManager *config = [ConfigManager globalConfig];
    [config registerDefaults:[self defaults]];
    _firstH = [config integerForKey:FIRST_HOUR];
    _lastH = [config integerForKey:LAST_HOUR];
    _minStep = [config integerForKey:MIN_STEP];
    _textAttributes = [[NSDictionary dictionaryWithObject:[NSColor textColor] forKey:NSForegroundColorAttributeName] retain];
    _backgroundColor = [[[NSColor controlBackgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] retain];
    _alternateBackgroundColor = [[_backgroundColor colorModifiedWithDeltaRed:0.05 green:0.05 blue:0.05 alpha:0] retain];
    [[NSNotificationCenter defaultCenter] addObserver:self
					     selector:@selector(configChanged:)
						 name:SAConfigManagerValueChanged
					       object:config];
    [[NSNotificationCenter defaultCenter] addObserver:self
					     selector:@selector(colorsDidChanged:)
						 name:NSSystemColorsDidChangeNotification
					       object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_backgroundColor release];
  [_alternateBackgroundColor release];
  [_textAttributes release];
  RELEASE(_date);
  [super dealloc];
}

- (int)minuteToSize:(int)minutes
{
  return minutes * [self frame].size.height / ((_lastH - _firstH + 1) * 60);
}
- (int)minuteToPosition:(int)minutes
{
  return [self frame].size.height - [self minuteToSize:minutes - (_firstH * 60)] - 1;
}
- (int)positionToMinute:(float)position
{
  return ((_lastH + 1) * 60) - ((_lastH - _firstH + 1) * 60) * position / [self frame].size.height;
}
- (int)distanceToDuration:(int)distance
{
  return ((_lastH - _firstH + 1) * 60) * distance / [self frame].size.height;
}

- (void)fixFrames
{
  int i, j, k, n;
  NSArray *subviews;
  AppointmentView *view, *next;
  NSRect fview, fnext, frame;
  float width, x;

  subviews = [[self subviews] sortedArrayUsingFunction:compareAppointmentViews context:NULL];
  if ([subviews count] < 2)
    return;
  for (i = 0; i < [subviews count] - 1; i++) {
    view = [subviews objectAtIndex:i];
    fview = [view frame];
    for (j = i + 1, n = 1; j < [subviews count]; j++) {
      next = [subviews objectAtIndex:j];
      fnext = [next frame];
      if (!NSIntersectsRect(fview, fnext))
	break;
      n++;
      fview = NSUnionRect(fview, fnext);
    }
    if (n != 1) {
      frame = [self frameForAppointment:[view appointment]];
      width  = frame.size.width / n;
      x = frame.origin.x;
      for (k = i; k < i + n; k++) {
	view = [subviews objectAtIndex:k];
	fview = [view frame];
	fview.size.width = width;
	fview.origin.x = x;
	x += width;
	[view setFrame:fview];
      }
    }
  }
}

- (NSRect)frameForAppointment:(Event *)apt
{
  NSRange range;
  int size, start;

  if ([apt allDay])
    return NSMakeRect(40, 0, [self frame].size.width - 48, [self frame].size.height);
  range = [apt intersectionWithDay:_date];
  start = [self minuteToPosition:range.location/60];
  size = [self minuteToSize:range.length/60];
  return NSMakeRect(40, start - size, [self frame].size.width - 48, size);
}

- (int)roundMinutes:(int)minutes
{
  return minutes / _minStep * _minStep;
}

- (void)drawRect:(NSRect)rect
{
  NSSize size;
  NSString *hour;
  int h, start;
  int hrow;
  float miny, maxy;

  [self fixFrames];
  /*
   * FIXME : if we draw the string in the same
   * loop it doesn't appear on the screen.
   */
  hrow = [self minuteToSize:60];
  for (h = _firstH; h <= _lastH + 1; h++) {
    start = [self minuteToPosition:h * 60];
    if (h % 2)
      [_backgroundColor set];
    else
      [_alternateBackgroundColor set];
    NSRectFill(NSMakeRect(0, start, rect.size.width, hrow + 1));
  }
  for (h = _firstH; h <= _lastH; h++) {
    hour = [NSString stringWithFormat:@"%d h", h];
    start = [self minuteToPosition:h * 60];
    size = [hour sizeWithAttributes:_textAttributes];
    [hour drawAtPoint:NSMakePoint(4, start - hrow / 2 - size.height / 2) withAttributes:_textAttributes];
  }
  if (_startPt.x != _endPt.x && _startPt.y != _endPt.y) {
    miny = MIN(_startPt.y, _endPt.y);
    maxy = MAX(_startPt.y, _endPt.y);
    [[NSColor grayColor] set];
    NSFrameRect(NSMakeRect(40, miny, rect.size.width - 48, maxy - miny));
  }
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
  _selected = aptv;
  [[SelectionManager globalManager] select:[aptv appointment]];
  if ([delegate respondsToSelector:@selector(viewSelectEvent:)])
    [delegate viewSelectEvent:[aptv appointment]];
  [self setNeedsDisplay:YES];
}

- (void)reloadData
{
  NSEnumerator *enumerator, *enm;
  AppointmentView *aptv;
  Event *apt;
  NSSet *events;
  BOOL found;

  events = [[StoreManager globalManager] visibleAppointmentsForDay:_date];
  enumerator = [[self subviews] objectEnumerator];
  while ((aptv = [enumerator nextObject])) {
    if (![events containsObject:[aptv appointment]] || ![[[aptv appointment] store] displayed]) {
      if (aptv == _selected)
	_selected = nil;
      [aptv removeFromSuperviewWithoutNeedingDisplay];
    }
  }
  enumerator = [events objectEnumerator];
  while ((apt = [enumerator nextObject])) {
    found = NO;
    enm = [[self subviews] objectEnumerator];
    while ((aptv = [enm nextObject])) {
      [aptv setFrame:[self frameForAppointment:[aptv appointment]]];
      if ([apt isEqual:[aptv appointment]]) {
	found = YES;
	break;
      }
    }
    if (found == NO) {
      if ([[apt store] displayed])
	[self addSubview:AUTORELEASE([[AppDayView alloc] initWithFrame:[self frameForAppointment:apt]  appointment:apt])];
    }
  }
  [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  int start;
  int end;
  BOOL keepOn = YES;
  NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];

  [[self window] makeFirstResponder:self];
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
    [self setNeedsDisplay:YES];
  }
  [NSCursor pop];
  if (ABS(_startPt.y - _endPt.y) > 7 && [self mouse:_endPt inRect:[self bounds]]) {
    start = [self positionToMinute:MAX(_startPt.y, _endPt.y)];
    end = [self positionToMinute:MIN(_startPt.y, _endPt.y)];
    if ([delegate respondsToSelector:@selector(viewCreateEventFrom:to:)])
      [delegate viewCreateEventFrom:[self roundMinutes:start] to:[self roundMinutes:end]];
  }
  _startPt = _endPt = NSMakePoint(0, 0);
  [self setNeedsDisplay:YES];
}

- (void)keyDown:(NSEvent *)theEvent
{
  NSString *characters = [theEvent characters];
  unichar character = 0;

  if ([characters length] > 0)
    character = [characters characterAtIndex: 0];

  switch (character) {
  case '\r':
  case NSEnterCharacter:
    if (_selected != nil) {
      if ([delegate respondsToSelector:@selector(viewEditEvent:)])
	[delegate viewEditEvent:[_selected appointment]];
    }
    break;
  case NSUpArrowFunctionKey:
    [self moveUp:self];
    break;
  case NSDownArrowFunctionKey:
    [self moveDown:self];
    break;
  case NSTabCharacter:
    if (_selected != nil) {
      NSUInteger index = [[self subviews] indexOfObject:_selected];
      if (index != NSNotFound) {
	if ([theEvent modifierFlags] & NSShiftKeyMask) {
	  if (index == 0)
	    index = [[self subviews] count] - 1;
	  else
	    index--;
	} else {
	  index++;
	  if (index >= [[self subviews] count])
	    index = 0;
	}
	[self selectAppointmentView:[[self subviews] objectAtIndex:index]];
      }
    } else {
      [self selectAppointmentView:[[self subviews] lastObject]];
    }
    break;
  default:
    [super keyDown:theEvent];
  }
}

- (void)moveUp:(id)sender
{
  if (_selected != nil) {
    [[[_selected appointment] startDate] changeMinuteBy:-_minStep];
    [_selected setFrame:[self frameForAppointment:[_selected appointment]]];
    if ([delegate respondsToSelector:@selector(viewModifyEvent:)])
      [delegate viewModifyEvent:[_selected appointment]];
  }
}

- (void)moveDown:(id)sender
{
  if (_selected != nil) {
    [[[_selected appointment] startDate] changeMinuteBy:_minStep];
    [_selected setFrame:[self frameForAppointment:[_selected appointment]]];
    if ([delegate respondsToSelector:@selector(viewModifyEvent:)])
      [delegate viewModifyEvent:[_selected appointment]];
  }
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (void)configChanged:(NSNotification *)not
{
  NSString *key = [[not userInfo] objectForKey:@"key"];
  ConfigManager *config = [ConfigManager globalConfig];

  if ([key isEqualToString:MIN_STEP])
    _minStep = [config integerForKey:MIN_STEP];
  else if ([key isEqualToString:FIRST_HOUR] || [key isEqualToString:LAST_HOUR]) {
    _firstH = [config integerForKey:FIRST_HOUR];
    _lastH = [config integerForKey:LAST_HOUR];
    /* FIXME : this should use a -refreshView method instead */
    [self reloadData];
  }
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

- (void)setDate:(Date *)date
{
  ASSIGNCOPY(_date, date);
  [self reloadData];
}
@end
