/* emacs objective-c mode -*- objc -*- */

#import "AgendaStore.h"
#import "AppointmentEditor.h"
#import "CalendarView.h"
#import "DayView.h"

@interface AppController : NSObject <DayViewDataSource>
{
  IBOutlet CalendarView *calendar;
  IBOutlet DayView *dayView;
  AppointmentEditor *editor;
  int _firstHour;
  int _lastHour;
  StoreManager *_sm;
  NSMutableSet *_cache;
  NSUserDefaults *_defaults;
  Appointment *_selection;
  BOOL _deleteSelection;
}

- (void)showPrefPanel:(id)sender;
- (void)addAppointment:(id)sender;
- (void)editAppointment:(id)sender;
- (void)delAppointment:(id)sender;
- (void)applicationWillTerminate:(NSNotification *)aNotification;
- (void)awakeFromNib;

@end
