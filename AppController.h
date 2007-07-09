/* emacs objective-c mode -*- objc -*- */

#import "AgendaStore.h"
#import "AppointmentEditor.h"
#import "CalendarView.h"
#import "DayView.h"
#import "Event.h"
#import "PreferencesController.h"

@interface AppController : NSObject <DayViewDataSource>
{
  IBOutlet CalendarView *calendar;
  IBOutlet DayView *dayView;
  IBOutlet NSOutlineView *summary;

  NSWindow *window;
  PreferencesController *_pc;
  AppointmentEditor *_editor;
  StoreManager *_sm;
  Event *_selection;
  BOOL _deleteSelection;
  AppointmentCache *_current;
  AppointmentCache *_today;
  AppointmentCache *_tomorrow;
  AppointmentCache *_soon;
}

- (void)copy:(id)sender;
- (void)cut:(id)sender;
- (void)paste:(id)sender;
- (void)editAppointment:(id)sender;
- (void)delAppointment:(id)sender;
- (void)exportAppointment:(id)sender;
- (void)saveAll:(id)sender;
- (void)showPrefPanel:(id)sender;
- (void)addAppointment:(id)sender;
- (void)editAppointment:(id)sender;
- (void)delAppointment:(id)sender;
- (void)exportAppointment:(id)sender;
@end
