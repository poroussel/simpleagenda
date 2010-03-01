/* emacs buffer mode hint -*- objc -*- */

#import "AppointmentView.h"
#import "defines.h"

static NSImage *_repeatImage;

@implementation AppointmentView
+ (void)initialize
{
  if (!_repeatImage) {
    _repeatImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:@"repeat"]];
    [_repeatImage setFlipped:YES];
  }
}

- (NSImage *)repeatImage
{
  return _repeatImage;
}

- (id)initWithFrame:(NSRect)frameRect appointment:(Event *)apt
{
  self = [super initWithFrame:frameRect];
  if (self) {
    ASSIGN(_apt, apt);
    [self tooltipSetup];
    [[ConfigManager globalConfig] registerClient:self forKey:TOOLTIP];
  }
  return self;
}

- (void)viewWillMoveToSuperview:(NSView *)newSuper
{
  /* Called with nil when the view is removed from its superview */
  if (nil == newSuper)
    [[ConfigManager globalConfig] unregisterClient:self];
}

- (void)dealloc
{
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
}
@end
