/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "Event.h"

@interface AppointmentView : NSView
{
  Event *_apt;
  BOOL _selected;
}
- (id)initWithFrame:(NSRect)frameRect appointment:(Event *)apt;
- (Event *)appointment;
- (void)setSelected:(BOOL)selected;
@end
