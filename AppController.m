/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "StoreManager.h"
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

- (void)initSummary
{
  DataTree *today = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:@"Today" forKey:@"title"]];
  DataTree *tomorrow = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:@"Tomorrow" forKey:@"title"]];
  _summaryRoot = [DataTree new];
  [_summaryRoot addChild:today];
  [_summaryRoot addChild:tomorrow];
}

- (NSDictionary *)attributesFrom:(Event *)event and:(Date *)date
{
  Date *today = [Date date];
  NSMutableDictionary *attributes = [NSMutableDictionary new];
  NSString *details;

  [date setMinute:[[event startDate] minuteOfDay]];
  [attributes setValue:event forKey:@"object"];
  [attributes setValue:[event title] forKey:@"title"];
  if ([today daysUntil:date] > 1 || [today daysSince:date] > 1)
    details = [[date calendarDate] descriptionWithCalendarFormat:@"%Y/%m/%d %H:%M"];
  else
    details = [[date calendarDate] descriptionWithCalendarFormat:@"%H:%M"];
  [attributes setValue:details forKey:@"details"];
  return AUTORELEASE(attributes);
}

- (void)updateSummaryData
{
  Date *today = [Date date];
  Date *tomorrow = [Date date];
  DataTree *ttoday = [[_summaryRoot children] objectAtIndex:0];
  DataTree *ttomorrow = [[_summaryRoot children] objectAtIndex:1];
  NSEnumerator *enumerator = [[_sm allEvents] objectEnumerator];
  Event *event;

  [ttoday removeChildren];
  [ttomorrow removeChildren];
  [tomorrow incrementDay];
  while ((event = [enumerator nextObject])) {
    if ([event isScheduledForDay:today])
      [ttoday addChild:[DataTree dataTreeWithAttributes:[self attributesFrom:event and:today]]];
    if ([event isScheduledForDay:tomorrow])
      [ttomorrow addChild:[DataTree dataTreeWithAttributes:[self attributesFrom:event and:tomorrow]]];
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
    [self initSummary];
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
  [_summaryRoot release];
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
    return [[_summaryRoot children] count];
  return [[item children] count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  return [[item children] count] > 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
  if (item == nil)
    return [[_summaryRoot children] objectAtIndex:index];
  return [[item children] objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
  return [item valueForKey:[tableColumn identifier]];
}
@end

@implementation AppController(NSOutlineViewDelegate)
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
  id object = [item valueForKey:@"object"];
  if (object && [object isKindOfClass:[Event class]])
    return YES;
  return NO;
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
