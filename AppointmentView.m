/* emacs buffer mode hint -*- objc -*- */

#import "AppointmentView.h"

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
  }
  return self;
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
@end
