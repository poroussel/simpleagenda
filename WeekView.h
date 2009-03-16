/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "ConfigManager.h"
#import "Event.h"
#import "StoreManager.h"
#import "AppointmentView.h"

@interface WeekView : NSView <ConfigListener>
{
  IBOutlet id <AgendaDataSource> dataSource;
  IBOutlet id delegate;
  int weekNumber;
}

- (void)selectAppointmentView:(AppointmentView *)aptv;
- (id)delegate;
- (void)reloadData;
@end

@interface NSObject(WeekViewDelegate)
- (void)editEvent:(Event *)event;
- (void)modifyEvent:(Event *)event;
- (void)createEvent;
- (void)selectEvent:(Event *)event;
@end
