/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "ConfigManager.h"
#import "StoreManager.h"
#import "AppointmentView.h"

@interface WeekView : NSView <ConfigListener>
{
  IBOutlet id <AgendaDataSource> dataSource;
  IBOutlet id delegate;
  int weekNumber;
}

- (void)selectAppointmentView:(AppointmentView *)aptv;
- (void)reloadData;
- (id)delegate;
@end
