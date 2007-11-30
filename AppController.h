/* emacs objective-c mode -*- objc -*- */

#import "AgendaStore.h"
#import "AppointmentEditor.h"
#import "TaskEditor.h"
#import "CalendarView.h"
#import "DayView.h"
#import "Element.h"
#import "Event.h"
#import "PreferencesController.h"
#import "DataTree.h"

@interface AppController : NSObject <DayViewDataSource>
{
  IBOutlet CalendarView *calendar;
  IBOutlet DayView *dayView;
  IBOutlet NSOutlineView *summary;
  IBOutlet NSTextField *search;
  IBOutlet NSTableView *taskView;
  IBOutlet NSWindow *window;
  IBOutlet NSTabView *tabs;

  PreferencesController *_pc;
  AppointmentEditor *_editor;
  TaskEditor *_taskEditor;
  StoreManager *_sm;
  Event *_selection;
  Element *_clickedElement;
  BOOL _deleteSelection;
  Date *_selectedDay;
  DataTree *_summaryRoot;
  DataTree *_today;
  DataTree *_tomorrow;
  DataTree *_soon;
  DataTree *_results;
  DataTree *_tasks;
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
- (void)addTask:(id)sender;
- (void)editAppointment:(id)sender;
- (void)delAppointment:(id)sender;
- (void)exportAppointment:(id)sender;
- (void)doSearch:(id)sender;
- (void)clearSearch:(id)sender;
@end
