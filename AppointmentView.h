/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "Event.h"

@interface NSObject(AppointmentViewDelegate)
- (void)viewEditEvent:(Event *)event;
- (void)viewModifyEvent:(Event *)event;
- (void)viewCreateEventFrom:(int)start to:(int)end;
- (void)viewSelectEvent:(Event *)event;
@end

@interface AppointmentView : NSView
{
  Event *_apt;
}
- (NSImage *)repeatImage;
- (id)initWithFrame:(NSRect)frameRect appointment:(Event *)apt;
- (Event *)appointment;
@end
