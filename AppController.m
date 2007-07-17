/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "StoreManager.h"
#import "AppointmentCache.h"
#import "AppController.h"
#import "Event.h"
#import "PreferencesController.h"
#import "iCalTree.h"

NSComparisonResult sortAppointments(Event *a, Event *b, void *data)
{
  return [[a startDate] compare:[b startDate]];
}

@implementation AppController

- (void)registerForServices
{
  NSArray *sendTypes = [NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil];
  NSArray *returnTypes = [NSArray arrayWithObjects:nil];
  [NSApp registerServicesMenuSendTypes: sendTypes returnTypes: returnTypes];
}

- (id)init
{
  Date *date;

  self = [super init];
  if (self) {
    _selection = nil;
    _editor = [AppointmentEditor new];
    _sm = [StoreManager new];
    _pc = [[PreferencesController alloc] initWithStoreManager:_sm];

    date = [Date new];
    _current = [[AppointmentCache alloc] initwithStoreManager:_sm date:date duration:1];
    [_current setDelegate:self];
    _today = [[AppointmentCache alloc] initwithStoreManager:_sm date:date duration:1];
    [_today setTitle:@"Today"];
    [date incrementDay];
    _tomorrow = [[AppointmentCache alloc] initwithStoreManager:_sm date:date duration:1];
    [_tomorrow setTitle:@"Tomorrow"];
    [date incrementDay];
    _soon = [[AppointmentCache alloc] initwithStoreManager:_sm date:date duration:3];
    [_soon setTitle:@"Soon"];
    [date release];
    [self registerForServices];
  }
  return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
  [window setFrameAutosaveName:@"mainWindow"];
  [dayView reloadData];
  [summary sizeToFit];
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
  [_soon release];
  [_tomorrow release];
  [_today release];
  [_current release];
  [_pc release];
  /* 
   * Ugly workaround : [_sm release] should force the
   * modified stores to synchronise their data but it 
   * doesn't work. We're leaking a object reference.
   */
  [_sm synchronise];
  [_sm release];
  [_editor release];
}


/* Called when user opens an .ics file in GWorkspace */
- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator *storeEnum;
  NSEnumerator *eventEnum;
  id <AgendaStore> store;
  Event *event;
  iCalTree *tree;

  if ([fm isReadableFileAtPath:filename]) {
    tree = [iCalTree new];
    [tree parseString:[NSString stringWithContentsOfFile:filename]];
    eventEnum = [[tree events] objectEnumerator];
    while ((event = [eventEnum nextObject])) {
      NSLog([event description]);
      storeEnum = [_sm objectEnumerator];
      while ((store = [storeEnum nextObject])) {
	if ([store contains:[event UID]])
	  NSLog(@"Event already is in %@", [store description]);
      }
      /* FIXME : determine if it's a new appointment or an update */
    }
    [tree release];
    return YES;
  }
  return NO;
}

- (void)showPrefPanel:(id)sender
{
  [_pc showPreferences];
}

- (int)_sensibleStartForDuration:(int)duration
{
  int minute = [dayView firstHour] * 60;
  NSArray *sorted = [[_current array] sortedArrayUsingFunction:sortAppointments context:nil];
  NSEnumerator *enumerator = [sorted objectEnumerator];
  Event *apt;

  while ((apt = [enumerator nextObject])) {
    if (minute + duration <= [[apt startDate] minuteOfDay])
      return minute;
    minute = [[apt startDate] minuteOfDay] + [apt duration];
  }
  if (minute < [dayView lastHour] * 60)
    return minute;
  return [dayView firstHour] * 60;
}

- (void)_editAppointment:(Event *)apt
{
  [_editor editAppointment:apt withStoreManager:_sm];
}

- (void)addAppointment:(id)sender
{
  Date *date = [[calendar date] copy];
  [date setMinute:[self _sensibleStartForDuration:60]];
  Event *apt = [[Event alloc] initWithStartDate:date 
					  duration:60
					  title:@"edit title..."];
  if (apt && [_editor editAppointment:apt withStoreManager:_sm]) {
    [dayView reloadData];
    [summary reloadData];
  }
  [date release];
  [apt release];
}

- (void)editAppointment:(id)sender
{
  Event *apt = [dayView selectedAppointment];

  if (apt)
    [self _editAppointment:apt];
}

- (void)delAppointment:(id)sender
{
  Event *apt = [dayView selectedAppointment];

  if (apt)
    [[apt store] remove:[apt UID]];
}

- (void)exportAppointment:(id)sender;
{
  Event *apt = [dayView selectedAppointment];
  NSSavePanel *panel = [NSSavePanel savePanel];
  NSString *str;
  iCalTree *tree;

  if (apt) {
    [panel setRequiredFileType:@"ics"];
    [panel setTitle:@"Export As"];
    if ([panel runModal] == NSOKButton) {
      tree = [iCalTree new];
      [tree add:apt];
      str = [tree iCalTreeAsString];
      if (![str writeToFile:[panel filename] atomically:NO])
	NSLog(@"Unable to write to file %@", [panel filename]);
      [tree release];
    }
  }
}

- (void)saveAll:(id)sender
{
  [_sm synchronise];
}

- (void)copy:(id)sender
{
  _selection = [dayView selectedAppointment];
  _deleteSelection = NO;
}

- (void)cut:(id)sender
{
  _selection = [dayView selectedAppointment];
  _deleteSelection = YES;
}

- (void)paste:(id)sender
{
  if (_selection && [[_selection store] isWritable]) {
    Date *date = [[calendar date] copy];
    if (_deleteSelection) {
      [date setMinute:[self _sensibleStartForDuration:[_selection duration]]];
      [_selection setStartDate:date];
      [[_selection store] update:[_selection UID] with:_selection];
      _selection = nil;
    } else {
      Event *new = [_selection copy];
      [date setMinute:[self _sensibleStartForDuration:[new duration]]];
      [new setStartDate:date];
      [[_selection store] add:new];
      [new release];
    }
    [date release];
  }
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  BOOL itemSelected = [dayView selectedAppointment] != nil;
  SEL action = [menuItem action];

  if (sel_eq(action, @selector(copy:)))
    return itemSelected;
  if (sel_eq(action, @selector(cut:)))
    return itemSelected;
  if (sel_eq(action, @selector(editAppointment:)))
    return itemSelected;
  if (sel_eq(action, @selector(delAppointment:)))
    return itemSelected;
  if (sel_eq(action, @selector(exportAppointment:)))
    return itemSelected;
  if (sel_eq(action, @selector(paste:)))
    return _selection != nil;
  return YES;
}

/* DayViewDataSource protocol */
- (NSEnumerator *)scheduledAppointmentsForDayView
{
  return [_current enumerator];
}

@end

@implementation AppController(NSOutlineViewDataSource)

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
  if (item == nil)
    return 3;
  if ([item isKindOfClass:[AppointmentCache class]])
    return [item count];
  return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  return YES;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
  if (item == nil) {
    if (index == 0)
      return _today;
    if (index == 1)
      return _tomorrow;
    return _soon;
  }
  return [[item array] objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
  if ([@"title" isEqual:[tableColumn identifier]])
    return [item title];
  return [item details];
}

@end

@implementation AppController(CalendarViewDelegate)

- (void)calendarView:(CalendarView *)cs selectedDateChanged:(Date *)date;
{
  [_current setDate:date];
  [dayView reloadData];
}

- (void)calendarView:(CalendarView *)cs currentDateChanged:(Date *)date;
{
  [_today setDate:date];
  [date incrementDay];
  [_tomorrow setDate:date];
  [date incrementDay];
  [_soon setDate:date];
  [summary reloadData];
}

@end

@implementation AppController(DayViewDelegate)

- (void)dayView:(DayView *)dayview editEvent:(Event *)event;
{
  /*
   * FIXME : we should allow to view appointment's 
   * details even if it's read only
   */
  if ([[event store] isWritable])
    [self _editAppointment:event];
}

/* FIXME : dayView:modifyEvent -> AgendaStore:updateAppointment -> SADataChangedInStore -> AppointmentCache populateFrom: -> DayView reloadData: -> refresh et perte de la selection */
- (void)dayView:(DayView *)dayview modifyEvent:(Event *)event
{
  [[event store] update:[event UID] with:event];
}

- (void)dayView:(DayView *)dayview createEventFrom:(int)start to:(int)end
{
  Date *date = [[calendar date] copy];
  [date setMinute:start];
  Event *apt = [[Event alloc] initWithStartDate:date 
			      duration:end - start 
			      title:@"edit title..."];
  if (apt)
    [_editor editAppointment:apt withStoreManager:_sm];
  [date release];
  [apt release];
}

@end

@implementation AppController(AppointmentCacheDelegate)

- (void)dataChangedInCache:(AppointmentCache *)ac
{
  [dayView reloadData];
  [summary reloadData];
}

@end
