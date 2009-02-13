/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "Event.h"

@interface AppointmentView : NSView
{
  Event *_apt;
}
- (NSImage *)repeatImage;
- (id)initWithFrame:(NSRect)frameRect appointment:(Event *)apt;
- (Event *)appointment;
@end
