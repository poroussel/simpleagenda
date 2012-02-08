/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "ConfigManager.h"
#import "StoreManager.h"
#import "AppointmentView.h"
#import "Date.h"

@interface WeekView : NSView
{
  IBOutlet id delegate;
  int weekNumber;
  int year;
  Date *_date;
}

- (void)selectAppointmentView:(AppointmentView *)aptv;
- (void)reloadData;
- (id)delegate;
- (void)setDate:(Date *)date;
@end
