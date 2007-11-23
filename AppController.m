/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "StoreManager.h"
#import "AppController.h"
#import "Event.h"
#import "Task.h"
#import "PreferencesController.h"
#import "iCalTree.h"

NSComparisonResult compareAppointments(id a, id b, void *data)
{
  return [[a startDate] compareTime:[b startDate]];
}

NSComparisonResult compareDataTreeElements(id a, id b, void *context)
{
  return [[[a valueForKey:@"object"] startDate] compareTime:[[b valueForKey:@"object"] startDate]];
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
  _today = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:@"Today" forKey:@"title"]];
  _tomorrow = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:@"Tomorrow" forKey:@"title"]];
  _soon = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:@"Soon" forKey:@"title"]];
  _results = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:@"Search results" forKey:@"title"]];
  _summaryRoot = [DataTree new];
  [_summaryRoot addChild:_today];
  [_summaryRoot addChild:_tomorrow];
  [_summaryRoot addChild:_soon];
  [_summaryRoot addChild:_results];
}

- (NSDictionary *)attributesFrom:(Event *)event and:(Date *)date
{
  Date *today = [Date today];
  NSMutableDictionary *attributes = [NSMutableDictionary new];
  NSString *details;

  [date setMinute:[[event startDate] minuteOfDay]];
  [attributes setValue:event forKey:@"object"];
  [attributes setValue:[date copy] forKey:@"date"];
  [attributes setValue:[event summary] forKey:@"title"];
  if ([today daysUntil:date] > 0 || [today daysSince:date] > 0)
    details = [[date calendarDate] descriptionWithCalendarFormat:@"%Y/%m/%d %H:%M"];
  else
    details = [[date calendarDate] descriptionWithCalendarFormat:@"%H:%M"];
  [attributes setValue:details forKey:@"details"];
  return AUTORELEASE(attributes);
}

- (void)updateSummaryData
{
  Date *today = [Date today];
  Date *tomorrow = [Date today];
  Date *soonStart = [Date today];
  Date *soonEnd = [Date today];
  NSEnumerator *enumerator = [[_sm allEvents] objectEnumerator];
  NSEnumerator *dayEnumerator;
  Event *event;
  Date *day;

  [_today removeChildren];
  [_tomorrow removeChildren];
  [_soon removeChildren];
  [tomorrow incrementDay];
  [soonStart changeDayBy:2];
  [soonEnd changeDayBy:5];
  while ((event = [enumerator nextObject])) {
    if ([event isScheduledForDay:today])
      [_today addChild:[DataTree dataTreeWithAttributes:[self attributesFrom:event and:today]]];
    if ([event isScheduledForDay:tomorrow])
      [_tomorrow addChild:[DataTree dataTreeWithAttributes:[self attributesFrom:event and:tomorrow]]];
    dayEnumerator = [soonStart enumeratorTo:soonEnd];
    while ((day = [dayEnumerator nextObject])) {
      if ([event isScheduledForDay:day])
	[_soon addChild:[DataTree dataTreeWithAttributes:[self attributesFrom:event and:day]]];
    }
  }
  [_today sortChildrenUsingFunction:compareDataTreeElements context:nil];
  [_tomorrow sortChildrenUsingFunction:compareDataTreeElements context:nil];
  [_soon sortChildrenUsingFunction:compareDataTreeElements context:nil];
  [summary reloadData];
}

- (id)init
{
  self = [super init];
  if (self) {
    ASSIGNCOPY(_selectedDay, [Date today]);
    _selection = nil;
    _editor = [AppointmentEditor new];
    _taskEditor = [TaskEditor new];
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
  NSPopUpButtonCell *cell = [NSPopUpButtonCell new];
  [cell addItemsWithTitles:[Task stateNamesArray]];
  [[taskView tableColumnWithIdentifier:@"state"] setDataCell:cell];
  [taskView setAutoresizesAllColumnsToFit:YES];
  /* 
   * FIXME : this shouldn't be needed but I can't make it
   * work by editing the interface with Gorm...
   * [[taskView superview] superview] is the ScrollView
   */
  [[[[taskView superview] superview] superview] setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [taskView setUsesAlternatingRowBackgroundColors:YES];
  [[taskView tableColumnWithIdentifier:@"state"] setMaxWidth:92];
  [taskView setTarget:self];
  [taskView setDoubleAction:@selector(editAppointment:)];
  [summary setAutoresizesAllColumnsToFit:YES];
  [summary setAutosaveName:@"summary"];
  [summary setAutosaveTableColumns:YES];
  [summary setTarget:self];
  [summary setDoubleAction:@selector(editAppointment:)];
  [window setFrameAutosaveName:@"mainWindow"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)not
{
  [dayView reloadData];
  [NSApp setServicesProvider: self];
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
  [_summaryRoot release];
  [_today release];
  [_tomorrow release];
  [_soon release];
  [_results release];
  [_pc release];
  /* 
   * Ugly workaround : [_sm release] should force the
   * modified stores to synchronise their data but it 
   * doesn't work. We're leaking a object reference.
   */
  [_sm synchronise];
  [_sm release];
  [_editor release];
  [_taskEditor release];
  RELEASE(_selectedDay);
}


/* Called when user opens an .ics file in GWorkspace */
- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator *eventEnum;
  id <AgendaStore> store;
  Element *elt;
  iCalTree *tree;

  if ([fm isReadableFileAtPath:filename]) {
    tree = [iCalTree new];
    [tree parseString:[NSString stringWithContentsOfFile:filename]];
    eventEnum = [[tree components] objectEnumerator];
    while ((elt = [eventEnum nextObject])) {
      store = [_sm storeContainingElement:elt];
      if (store)
	[store update:elt];
      else {
	if ([elt isKindOfClass:[Event class]])
	  [[_sm defaultStore] addEvent:(Event *)elt];
	else
	  [[_sm defaultStore] addTask:(Task *)elt];
      }
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
  NSArray *sorted = [[_sm allEvents] sortedArrayUsingFunction:compareAppointments context:nil];
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

- (void)addAppointment:(id)sender
{
  Date *date = [[calendar date] copy];
  [date setMinute:[self _sensibleStartForDuration:60]];
  Event *apt = [[Event alloc] initWithStartDate:date 
					  duration:60
					  title:@"edit title..."];
  if (apt && [_editor editAppointment:apt withStoreManager:_sm])
    [tabs selectTabViewItemWithIdentifier:@"Day"];
  [date release];
  [apt release];
}

- (void)addTask:(id)sender
{
  Task *task = [[Task alloc] initWithSummary:@"edit summary..."];
  if (task && [_taskEditor editTask:task withStoreManager:_sm])
    [tabs selectTabViewItemWithIdentifier:@"Tasks"];
  [task release];
}

- (void)newTask:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  NSString *aString;
  NSArray *allTypes;
  Task *task;

  allTypes = [pboard types];  
  if (![allTypes containsObject: NSStringPboardType]) {
    *error = @"No string type supplied on pasteboard";
    return;
  }
  aString = [pboard stringForType: NSStringPboardType];
  if (aString == nil) {
    *error = @"No string value supplied on pasteboard";
    return;
  }
  task = [Task new];
  if ([aString length] > 40) {
    [task setSummary:@"New note"];
    [task setText:AUTORELEASE([[NSAttributedString alloc ] initWithString:aString])];
  } else
    [task setSummary:aString];
  if (task && [_taskEditor editTask:task withStoreManager:_sm])
    [tabs selectTabViewItemWithIdentifier:@"Tasks"];
  [task release];
}

- (void)editAppointment:(id)sender
{
  if (_clickedElement) {
    if ([_clickedElement isKindOfClass:[Event class]])
      [_editor editAppointment:(Event *)_clickedElement withStoreManager:_sm];
    else
      [_taskEditor editTask:(Task *)_clickedElement withStoreManager:_sm];
  }
}

- (void)delAppointment:(id)sender
{
  if (_clickedElement) {
    [[_clickedElement store] remove:_clickedElement];
    _clickedElement = nil;
  }
}

- (void)exportAppointment:(id)sender;
{
  NSSavePanel *panel = [NSSavePanel savePanel];
  NSString *str;
  iCalTree *tree;

  if (_clickedElement) {
    [panel setRequiredFileType:@"ics"];
    [panel setTitle:@"Export as"];
    if ([panel runModalForDirectory:nil file:[_clickedElement summary]] == NSOKButton) {
      tree = [iCalTree new];
      [tree add:_clickedElement];
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
  _selection = (Event *)_clickedElement;
  _deleteSelection = NO;
}

- (void)cut:(id)sender
{
  _selection = (Event *)_clickedElement;
  _deleteSelection = YES;
}

- (void)paste:(id)sender
{
  if (_selection && [[_selection store] writable]) {
    Date *date = [[calendar date] copy];
    if (_deleteSelection) {
      [date setMinute:[self _sensibleStartForDuration:[_selection duration]]];
      [_selection setStartDate:date];
      [[_selection store] update:_selection];
      _selection = nil;
    } else {
      Event *new = [_selection copy];
      [new generateUID];
      [date setMinute:[self _sensibleStartForDuration:[new duration]]];
      [new setStartDate:date];
      [[_selection store] addEvent:new];
      [new release];
    }
    [date release];
  }
}

- (void)performSearch
{
  NSEnumerator *enumerator;
  Event *event;

  [_results removeChildren];
  if ([[search stringValue] length] > 0) {
    enumerator = [[_sm allEvents] objectEnumerator];
    while ((event = [enumerator nextObject])) {
      if ([event contains:[search stringValue]])
	[_results addChild:[DataTree dataTreeWithAttributes:[self attributesFrom:event and:[event startDate]]]];
    }
    [_results setValue:[NSString stringWithFormat:@"%d item(s)", [[_results children] count]] forKey:@"details"];;
    [_results sortChildrenUsingFunction:compareDataTreeElements context:nil];
    [summary expandItem:_results];
  }
}

- (void)doSearch:(id)sender
{
  [self performSearch];
  [summary reloadData];
  [window makeFirstResponder:search];
}

- (void)clearSearch:(id)sender
{
  [search setStringValue:@""];
  [_results removeChildren];
  [_results setValue:@"" forKey:@"details"];;
  [summary reloadData];
  [window makeFirstResponder:search];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  BOOL itemSelected = _clickedElement != nil;
  SEL action = [menuItem action];

  if (sel_eq(action, @selector(copy:)))
    return itemSelected && [_clickedElement isKindOfClass:[Event class]];
  if (sel_eq(action, @selector(cut:)))
    return itemSelected && [_clickedElement isKindOfClass:[Event class]];
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

  if (object && [object isKindOfClass:[Event class]]) {
    _clickedElement = object;
    [calendar setDate:[item valueForKey:@"date"]];
    [tabs selectTabViewItemWithIdentifier:@"Day"];
    return YES;
  }
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
  [_editor editAppointment:event withStoreManager:_sm];
}
- (void)dayView:(DayView *)dayview modifyEvent:(Event *)event
{
  [[event store] update:event];
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
- (void)dayView:(DayView *)dayview selectEvent:(Event *)event
{
  _clickedElement = event;
}
@end

@implementation AppController(StoreManagerDelegate)
- (void)dataChangedInStoreManager:(StoreManager *)sm
{
  [dayView reloadData];
  [taskView reloadData];
  [self performSearch];
  [self updateSummaryData];
}
@end

@implementation AppController(NSTableDataSource)
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [[_sm allTasks] count];
}
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  return NO;
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  Task *task = [[_sm allTasks] objectAtIndex:rowIndex];

  if ([[aTableColumn identifier] isEqualToString:@"summary"])
    return [task summary];
  return [NSNumber numberWithInt:[task state]];
}
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  Task *task = [[_sm allTasks] objectAtIndex:rowIndex];

  if ([[task store] writable]) {
    [task setState:[anObject intValue]];
    [[task store] update:task];
  }
}
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  Task *task;

  if ([[aTableColumn identifier] isEqualToString:@"state"]) {
    task = [[_sm allTasks] objectAtIndex:rowIndex];
    [aCell setEnabled:[[task store] writable]];
  }
}
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  int index = [taskView selectedRow];
  if (index > -1)
    _clickedElement = [[_sm allTasks] objectAtIndex:index];
}
@end

