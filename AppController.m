/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "StoreManager.h"
#import "AppController.h"
#import "Event.h"
#import "PreferencesController.h"
#import "iCalTree.h"

@interface SummaryData : NSObject
{
  NSString *_title;
  NSMutableArray *_events;
}
- (id)initWithTitle:(NSString *)title;
- (NSString *)title;
- (unsigned int)count;
- (void)flush;
- (void)addEvent:(Event *)event;
- (Event *)eventAtIndex:(int)index;
@end

@implementation SummaryData
- (id)initWithTitle:(NSString *)title
{
  self = [super init];
  if (self) {
    ASSIGN(_title, title);
    _events = [NSMutableArray new];
  }
  return self;
}
- (void)dealloc
{
  [_events release];
  RELEASE(_title);
  [super dealloc];
}
- (NSString *)title
{
  return _title;
}
- (unsigned int)count
{
  return [_events count];
}
- (void)flush
{
  [_events removeAllObjects];
}
- (void)addEvent:(Event *)event
{
  [_events addObject:event];
}
- (Event *)eventAtIndex:(int)index
{
  return [_events objectAtIndex:index];
}
@end



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

- (void)updateSummaryData
{
  Date *today = [Date date];
  Date *tomorrow = [Date date];
  NSEnumerator *enumerator = [[_sm allEvents] objectEnumerator];
  SummaryData *sd0, *sd1;
  Event *event;

  [tomorrow incrementDay];
  sd0 = [_summarySections objectAtIndex:0];
  sd1 = [_summarySections objectAtIndex:1];
  [sd0 flush];
  [sd1 flush];
  while ((event = [enumerator nextObject])) {
    if ([event isScheduledForDay:today])
      [sd0 addEvent:event];
    if ([event isScheduledForDay:tomorrow])
      [sd1 addEvent:event];
  }
  [summary reloadData];
}

- (id)init
{
  self = [super init];
  if (self) {
    ASSIGNCOPY(_selectedDay, [Date date]);
    _selection = nil;
    _editor = [AppointmentEditor new];
    _sm = [StoreManager new];
    _pc = [[PreferencesController alloc] initWithStoreManager:_sm];
    [_sm setDelegate:self];
    _summarySections = [[NSArray alloc] initWithObjects:[[SummaryData alloc] initWithTitle:@"Today"], 
					[[SummaryData alloc] initWithTitle:@"Tomorrow"], nil];
    [self updateSummaryData];
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
  [_summarySections release];
  RELEASE(_selectedDay);
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
  NSEnumerator *eventEnum;
  id <AgendaStore> store;
  Event *event;
  iCalTree *tree;

  if ([fm isReadableFileAtPath:filename]) {
    tree = [iCalTree new];
    [tree parseString:[NSString stringWithContentsOfFile:filename]];
    eventEnum = [[tree events] objectEnumerator];
    while ((event = [eventEnum nextObject])) {
      store = [_sm storeContainingEvent:event];
      if (store)
	[store update:[event UID] with:event];
      else
	[[_sm defaultStore] add:event];
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
  NSArray *sorted = [[_sm allEvents] sortedArrayUsingFunction:sortAppointments context:nil];
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
      [new generateUID];
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
- (NSSet *)scheduledAppointmentsForDayView
{
  NSMutableSet *dayEvents = [NSMutableSet setWithCapacity:8];
  NSEnumerator *enumerator = [[_sm allEvents] objectEnumerator];
  Event *event;

  while ((event = [enumerator nextObject]))
    if ([event isScheduledForDay:_selectedDay])
      [dayEvents addObject:event];
  return dayEvents;
}

@end

@implementation AppController(NSOutlineViewDataSource)

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
  if (item == nil)
    return [_summarySections count];
  if ([item isKindOfClass:[SummaryData class]])
    return [item count];
  return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  if ([item isKindOfClass:[Event class]])
    return NO;
  return YES;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
  if (item == nil)
    return [_summarySections objectAtIndex:index];
  return [item eventAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
  if ([item isKindOfClass:[SummaryData class]]) {
    if ([@"title" isEqual:[tableColumn identifier]])
      return [item title];
    return [NSString stringWithFormat:@"%d item(s)", [item count]];
  }
  if ([item isKindOfClass:[Event class]]) {
    if ([@"title" isEqual:[tableColumn identifier]])
      return [item title];
    return [item details];
  }
  return @"";
}
@end

@implementation AppController(CalendarViewDelegate)
- (void)calendarView:(CalendarView *)cs selectedDateChanged:(Date *)date;
{
  ASSIGNCOPY(_selectedDay, date);
  [dayView reloadData];
}
- (void)calendarView:(CalendarView *)cs currentDateChanged:(Date *)date;
{
  [self updateSummaryData];
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

@implementation AppController(StoreManagerDelegate)
- (void)dataChangedInStoreManager:(StoreManager *)sm
{
  [dayView reloadData];
  [self updateSummaryData];
}
@end
