/* emacs buffer mode hint -*- objc -*- */

#import "AppointmentView.h"

static NSImage *_repeatImage;

@implementation AppointmentView
- (NSImage *)repeatImage
{
  if (!_repeatImage) {
    NSString *path = [[NSBundle mainBundle] pathForImageResource:@"repeat"];
    _repeatImage = [[NSImage alloc] initWithContentsOfFile:path];
    [_repeatImage setFlipped:YES];
  }
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
