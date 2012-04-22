/* emacs buffer mode hint -*- objc -*- */

#import "AppointmentView.h"
#import "defines.h"

static NSImage *_repeatImage;
static NSImage *_alarmImage;

@implementation AppointmentView
+ (void)initialize
{
  _repeatImage = [NSImage imageNamed:@"repeat.tiff"];
  _alarmImage = [NSImage imageNamed:@"small-bell.tiff"];
}

- (NSImage *)repeatImage
{
  return _repeatImage;
}

- (NSImage *)alarmImage
{
  return _alarmImage;
}

- (id)initWithFrame:(NSRect)frameRect appointment:(Event *)apt
{
  if ((self = [super initWithFrame:frameRect])) {
    ASSIGN(_apt, apt);
    [self tooltipSetup];
    [[NSNotificationCenter defaultCenter] addObserver:self 
					     selector:@selector(configChanged:) 
						 name:SAConfigManagerValueChanged 
					       object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  RELEASE(_apt);
  [super dealloc];
}

- (Event *)appointment
{
  return _apt;
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
  NSMenu *menu;
  <NSMenuItem> item;

  if ([event type] != NSRightMouseDown)
    return nil;

  menu = [[NSMenu alloc] initWithTitle:_(@"Appointment")];
  if ([_apt sticky])
    item = [menu insertItemWithTitle:_(@"Unset sticky") action:@selector(changeSticky:) keyEquivalent:nil atIndex:0];
  else
    item = [menu insertItemWithTitle:_(@"Set sticky") action:@selector(changeSticky:) keyEquivalent:nil atIndex:0];
  [item setTarget:self];
  return [menu autorelease];
}

- (void)changeSticky:(id)sender
{
  [_apt setSticky:![_apt sticky]];
  [[_apt store] update:_apt];
  [self setNeedsDisplay:YES];
}

- (void)tooltipSetup
{
  NSAttributedString *as = [_apt text];

  if ([[ConfigManager globalConfig] integerForKey:TOOLTIP] && as && [as length] > 0)
    [self setToolTip:[as string]];
  else
    [self setToolTip:nil];
}

- (void)configChanged:(NSNotification *)not
{
  NSString *key = [[not userInfo] objectForKey:@"key"];
  if ([key isEqualToString:TOOLTIP])
    [self tooltipSetup];
  else if ([key isEqualToString:ST_COLOR] || [key isEqualToString:ST_TEXT_COLOR])
    [self setNeedsDisplay:YES];
}
@end
