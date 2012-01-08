/* emacs objective-c mode -*- objc -*- */

#import "AgendaStore.h"
#import "CalendarView.h"
#import "DayView.h"
#import "WeekView.h"
#import "Element.h"
#import "Event.h"
#import "PreferencesController.h"
#import "DataTree.h"
#import "SelectionManager.h"
#import "ConfigManager.h"
#import "AlarmManager.h"

@interface AppController : NSObject
{
  IBOutlet CalendarView *calendar;
  IBOutlet DayView *dayView;
  IBOutlet WeekView *weekView;
  IBOutlet NSOutlineView *summary;
  IBOutlet NSTextField *search;
  IBOutlet NSTableView *taskView;
  IBOutlet NSWindow *window;
  IBOutlet NSTabView *tabs;

  PreferencesController *_pc;
  StoreManager *_sm;
  SelectionManager *_selm;
  AlarmManager *_am;
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
- (void)reloadAll:(id)sender;
- (void)showPrefPanel:(id)sender;
- (void)addAppointment:(id)sender;
- (void)addTask:(id)sender;
- (void)editAppointment:(id)sender;
- (void)delAppointment:(id)sender;
- (void)exportAppointment:(id)sender;
- (void)doSearch:(id)sender;
- (void)clearSearch:(id)sender;
- (void)today:(id)sender;
- (void)nextDay:(id)sender;
- (void)previousDay:(id)sender;
- (void)nextWeek:(id)sender;
- (void)previousWeek:(id)sender;
- (void)updateSummaryData;
- (void)dataChanged:(NSNotification *)not;
@end
