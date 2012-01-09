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
  self = [super initWithFrame:frameRect];
  if (self) {
    ASSIGN(_apt, apt);
    [self tooltipSetup];
    [[ConfigManager globalConfig] registerClient:self forKey:TOOLTIP];
    [[ConfigManager globalConfig] registerClient:self forKey:ST_COLOR];
    [[ConfigManager globalConfig] registerClient:self forKey:ST_TEXT_COLOR];
  }
  return self;
}

- (void)dealloc
{
  [[ConfigManager globalConfig] unregisterClient:self];
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

- (void)tooltipSetup
{
  NSAttributedString *as = [_apt text];

  if ([[ConfigManager globalConfig] integerForKey:TOOLTIP] && as && [as length] > 0)
    [self setToolTip:[as string]];
  else
    [self setToolTip:nil];
}

- (void)config:(ConfigManager *)config dataDidChangedForKey:(NSString *)key
{
  if ([key isEqualToString:TOOLTIP])
    [self tooltipSetup];
  else
    [self setNeedsDisplay:YES];
}
@end
