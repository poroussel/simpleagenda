/* emacs objective-c mode -*- objc -*- */

#import "AgendaStore.h"
#import "AppointmentEditor.h"
#import "CalendarView.h"
#import "DayView.h"
#import "Event.h"
#import "PreferencesController.h"
#import "UserDefaults.h"

@interface AppController : NSObject <DayViewDataSource, DefaultsConsumer>
{
  IBOutlet CalendarView *calendar;
  IBOutlet DayView *dayView;
  IBOutlet NSOutlineView *summary;

  PreferencesController *_pc;
  AppointmentEditor *_editor;
  UserDefaults *_defaults;
  StoreManager *_sm;
  Event *_selection;
  BOOL _deleteSelection;
  AppointmentCache *_current;
  AppointmentCache *_today;
  AppointmentCache *_tomorrow;
  AppointmentCache *_soon;
}

- (void)showPrefPanel:(id)sender;
- (void)addAppointment:(id)sender;
- (void)editAppointment:(id)sender;
- (void)delAppointment:(id)sender;

@end
