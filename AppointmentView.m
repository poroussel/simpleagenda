/* emacs buffer mode hint -*- objc -*- */

#import "AppointmentView.h"

@implementation AppointmentView
- (id)initWithFrame:(NSRect)frameRect appointment:(Event *)apt;
{
  self = [super initWithFrame:frameRect];
  if (self) {
    ASSIGN(_apt, apt);
    _selected = NO;
  }
  return self;
}
- (void)dealloc
{
  RELEASE(_apt);
  [super dealloc];
}
- (BOOL)selected
{
  return _selected;
}
- (void)setSelected:(BOOL)selected
{
  _selected = selected;
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
