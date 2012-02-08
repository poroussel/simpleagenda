/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "Event.h"
#import "ConfigManager.h"

@interface NSObject(AppointmentViewDelegate)
- (void)viewEditEvent:(Event *)event;
- (void)viewModifyEvent:(Event *)event;
- (void)viewCreateEventFrom:(int)start to:(int)end;
- (void)viewSelectEvent:(Event *)event;
- (void)viewSelectDate:(Date *)date;
@end

@interface AppointmentView : NSView
{
  Event *_apt;
}
- (NSImage *)repeatImage;
- (NSImage *)alarmImage;
- (id)initWithFrame:(NSRect)frameRect appointment:(Event *)apt;
- (Event *)appointment;
- (void)tooltipSetup;
@end
