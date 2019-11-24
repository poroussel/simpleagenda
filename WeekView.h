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
  id _dataSource;
}

- (void)selectAppointmentView:(AppointmentView *)aptv;
- (id)delegate;
- (void)setDate:(Date *)date;
- (id)dataSource;
- (void)setDataSource:(id)dataSource;
- (void)dataChanged:(NSNotification *)not;
- (void)reloadData;
@end
