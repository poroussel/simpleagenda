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
  AppointmentEditor *editor;
  StoreManager *_sm;
  NSMutableSet *_cache;
  Event *_selection;
  PreferencesController *_pc;
  BOOL _deleteSelection;
}

- (void)showPrefPanel:(id)sender;
- (void)addAppointment:(id)sender;
- (void)editAppointment:(id)sender;
- (void)delAppointment:(id)sender;
- (void)awakeFromNib;

@end
