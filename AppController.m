/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "TaskEditor.h"
#import "StoreManager.h"
#import "AppController.h"
#import "Event.h"
#import "Task.h"
#import "PreferencesController.h"
#import "iCalTree.h"
#import "SelectionManager.h"
#import "AlarmManager.h"

NSComparisonResult compareDataTreeElements(id a, id b, void *context)
{
  return [[[a valueForKey:@"object"] startDate] compareTime:[[b valueForKey:@"object"] startDate]];
}

@implementation AppController
- (void)registerForServices
{
  [NSApp registerServicesMenuSendTypes: [NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]
	                   returnTypes: [NSArray arrayWithObjects:nil]];
}

- (void)initSummary
{
  _today = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:_(@"Today") forKey:@"title"]];
  _tomorrow = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:_(@"Tomorrow") forKey:@"title"]];
  _soon = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:_(@"Soon") forKey:@"title"]];
  _results = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:_(@"Search results") forKey:@"title"]];
  _tasks = [DataTree dataTreeWithAttributes:[NSDictionary dictionaryWithObject:_(@"Open tasks") forKey:@"title"]];
  _summaryRoot = [DataTree new];
  [_summaryRoot addChild:_today];
  [_summaryRoot addChild:_tomorrow];
  [_summaryRoot addChild:_soon];
  [_summaryRoot addChild:_results];
  [_summaryRoot addChild:_tasks];
}

- (NSDictionary *)attributesFrom:(Event *)event and:(Date *)date
{
  Date *today = [Date today];
  Date *copy = AUTORELEASE([date copy]);
  NSMutableDictionary *attributes = [NSMutableDictionary new];
  NSString *details;
  NSString *title;

  [copy setIsDate:NO];
  [copy setMinute:[[event startDate] minuteOfDay]];
  [attributes setValue:event forKey:@"object"];
  [attributes setValue:copy forKey:@"date"];
  if ([today timeIntervalSinceDate:copy] > 86400 || [today timeIntervalSinceDate:copy] < -86400)
    details = [[copy calendarDate] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortDateFormatString]];
  else
    details = [[copy calendarDate] descriptionWithCalendarFormat:@"%H:%M"];
  title = [NSString stringWithFormat:@"%@ : %@", details, [event summary]];
  [attributes setValue:title forKey:@"title"];
  return AUTORELEASE(attributes);
}

- (NSDictionary *)attributesFromTask:(Task *)task
{
  return [NSMutableDictionary dictionaryWithObjectsAndKeys:task, @"object", [task summary], @"title", nil, nil];
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
  Task *task;

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
  [_tasks removeChildren];
  enumerator = [[_sm allTasks] objectEnumerator];
  while ((task = [enumerator nextObject])) {
    if ([task state] != TK_COMPLETED)
      [_tasks addChild:[DataTree dataTreeWithAttributes:[self attributesFromTask:task]]];
  }
  [_tasks setValue:[NSString stringWithFormat:_(@"Open tasks (%d)"), [[_tasks children] count]] forKey:@"title"];
  [summary reloadData];
}

- (id)init
{
  self = [super init];
  if (self) {
    ASSIGNCOPY(_selectedDay, [Date today]);
    selectionManager = [SelectionManager globalManager];
    _sm = [StoreManager globalManager];
    _pc = [PreferencesController new];
    [self initSummary];
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
   * 
   * Edit : I don't know if the bug comes from Gorm or
   * NSTabView but here's an explanation : there is a NSView
   * between NSTabView and each tab view (NSTabView -> NSView -> DayView,
   * NSTabView -> NSView -> WeekView etc) and, except for the first tab,
   * the intermediate view's autoresizingMask is 0
   */
  [[[[taskView superview] superview] superview] setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [[weekView superview] setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [taskView setUsesAlternatingRowBackgroundColors:YES];
  [[taskView tableColumnWithIdentifier:@"state"] setMaxWidth:92];
  [taskView setTarget:self];
  [taskView setDoubleAction:@selector(editAppointment:)];
  [summary sizeLastColumnToFit];
  [summary setTarget:self];
  [summary setDoubleAction:@selector(editAppointment:)];
  [window setFrameAutosaveName:@"mainWindow"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)not
{
  [NSApp setServicesProvider: self];
  /*
   * We should register these notifications before allocating
   * the StoreManager to get all data updates. To avoid
   * numerous invisible updates which would slow the startup,
   * register only when the application is ready and force
   * a global refresh with a false notification
   */
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataChanged:) name:SADataChanged object:nil];
  /* FIXME : this is overkill, we should only refresh the views for visual changes */
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataChanged:) name:SAStatusChangedForStore object:nil];
  [self dataChanged:nil];
  /* This will init the alarms for all loaded elements needing one */
  [AlarmManager globalManager];
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_summaryRoot release];
  [_pc release];
  /* 
   * FIXME : we shouldn't have to release the store
   * manager as we don't retain it. It's a global
   * instance that should synchronise itself when
   * it's freed
   */
  [_sm release];
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
      else
	[[_sm defaultStore] add:elt];
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
  NSEnumerator *enumerator = [[self scheduledAppointmentsForDay:_selectedDay] objectEnumerator];
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
  Event *apt;
  Date *date;

  date = [[calendar date] copy];
  [date setIsDate:NO];
  [date setMinute:[self _sensibleStartForDuration:60]];
  apt = [[Event alloc] initWithStartDate:date duration:60 title:_(@"edit title...")];
  [AppointmentEditor editorForEvent:apt];
  [date release];
  [apt release];
}

- (void)addTask:(id)sender
{
  Task *task = [[Task alloc] initWithSummary:_(@"edit summary...")];
  if (task && [TaskEditor editorForTask:task])
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
    [task setSummary:_(@"New task")];
    [task setText:AUTORELEASE([[NSAttributedString alloc ] initWithString:aString])];
  } else
    [task setSummary:aString];
  if (task && [TaskEditor editorForTask:task])
    [tabs selectTabViewItemWithIdentifier:@"Tasks"];
  [task release];
}

- (void)editAppointment:(id)sender
{
  id lastSelection = [selectionManager lastObject];

  if (lastSelection) {
    if ([lastSelection isKindOfClass:[Event class]])
      [AppointmentEditor editorForEvent:(Event *)lastSelection];
    else if ([lastSelection isKindOfClass:[Task class]])
      [TaskEditor editorForTask:(Task *)lastSelection];
    else
      NSLog(@"We should never come here...");
  }
}

- (void)delAppointment:(id)sender
{
  NSEnumerator *enumerator = [selectionManager enumerator];
  Element *el;

  while ((el = [enumerator nextObject]))
    [[el store] remove:el];
  [selectionManager clear];
}

- (void)exportAppointment:(id)sender;
{
  NSEnumerator *enumerator = [selectionManager enumerator];
  NSSavePanel *panel = [NSSavePanel savePanel];
  NSString *str;
  iCalTree *tree;
  Element *el;

  if ([selectionManager count] > 0) {
    [panel setRequiredFileType:@"ics"];
    [panel setTitle:_(@"Export as")];
    if ([panel runModalForDirectory:nil file:[[selectionManager lastObject] summary]] == NSOKButton) {
      tree = [iCalTree new];
      while ((el = [enumerator nextObject]))
	[tree add:el];
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

- (void)reloadAll:(id)sender
{
  [_sm refresh];
}

- (void)copy:(id)sender
{
  [selectionManager copySelection];
}

- (void)cut:(id)sender
{
  [selectionManager cutSelection];
}

- (void)paste:(id)sender
{
  if ([selectionManager copiedCount] > 0) {
    NSEnumerator *enumerator = [[selectionManager paste] objectEnumerator];
    Date *date = [[calendar date] copy];
    Event *el;
    id <MemoryStore> store;

    [date setIsDate:NO];
    while ((el = [enumerator nextObject])) {
      /* FIXME : store property could be handled by Event:copy ? */
      store = [el store];
      if ([selectionManager lastOperation] == SMCopy) {
	el = [el copy];
	[date setMinute:[self _sensibleStartForDuration:[el duration]]];
      } else {
	[date setMinute:[[el startDate] minuteOfDay]];
      }
      [el setStartDate:date];
      if ([selectionManager lastOperation] == SMCopy) {
	[store add:el];
	/*
	 * FIXME : the new event is now in store's dictionary, we 
	 * should be able to release it. If we do, the application 
	 * crashes when we delete this event, trying to release it
	 * one time too many. I can't find the bug
	 * [el release];
	 */
      } else {
	[store update:el];
      }     
    }
    [date release];
  }
}

- (void)today:(id)sender
{
  [calendar setDate:[Date today]];
}
- (void)nextDay:(id)sender
{
  [calendar setDate:[Date dateWithTimeInterval:86400 sinceDate:[calendar date]]];
}

- (void)previousDay:(id)sender
{
  [calendar setDate:[Date dateWithTimeInterval:-86400 sinceDate:[calendar date]]];
}

- (void)nextWeek:(id)sender
{
  [calendar setDate:[Date dateWithTimeInterval:86400*7 sinceDate:[calendar date]]];
}

- (void)previousWeek:(id)sender
{
  [calendar setDate:[Date dateWithTimeInterval:86400*-7 sinceDate:[calendar date]]];
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
    [_results sortChildrenUsingFunction:compareDataTreeElements context:nil];
    [summary expandItem:_results];
    [_results setValue:[NSString stringWithFormat:_(@"Search results (%d items)"), [[_results children] count]] forKey:@"title"];
  } else
    [_results setValue:_(@"Search results") forKey:@"title"];
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
  [self performSearch];
  [summary reloadData];
  [window makeFirstResponder:search];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  SEL action = [menuItem action];

  if (sel_eq(action, @selector(copy:)))
    return [selectionManager count] > 0;
  if (sel_eq(action, @selector(cut:)))
    return [selectionManager count] > 0;
  if (sel_eq(action, @selector(editAppointment:)))
    return [selectionManager count] == 1;
  if (sel_eq(action, @selector(delAppointment:)))
    return [selectionManager count] > 0;
  if (sel_eq(action, @selector(exportAppointment:)))
    return [selectionManager count] > 0;
  if (sel_eq(action, @selector(paste:)))
    return [selectionManager copiedCount] > 0;
  return YES;
}

/* AgendaDataSource protocol */
/* FIXME : this should probably go in StoreManager */
- (NSSet *)scheduledAppointmentsForDay:(Date *)date
{
  NSMutableSet *dayEvents = [NSMutableSet setWithCapacity:8];
  NSEnumerator *enumerator = [[_sm allEvents] objectEnumerator];
  Event *event;

  NSAssert(date != nil, @"No date specified, am I supposed to guess ?");
  while ((event = [enumerator nextObject]))
    if ([event isScheduledForDay:date])
      [dayEvents addObject:event];
  return dayEvents;
}
- (Date *)selectedDate
{
  return [calendar date];
}

- (void)dataChanged:(NSNotification *)not
{
  /* 
   * FIXME : if a selected event was deleted by another application, 
   * the selection will reference a non existing object
   */
  [dayView reloadData];
  [weekView reloadData];
  [taskView reloadData];
  [self performSearch];
  [self updateSummaryData];
}

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
{
  if ([selectionManager count] && (!sendType || [sendType isEqual:NSFilenamesPboardType] || [sendType isEqual:NSStringPboardType]))
    return self;
  return nil;
}
- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
  NSEnumerator *enumerator = [selectionManager enumerator];
  Element *el;
  NSString *ical;
  NSString *filename;
  iCalTree *tree;
  NSFileWrapper *fw;
  BOOL written;

  if ([selectionManager count] == 0)
    return NO;
  NSAssert([types count] == 1, @"It seems our assumption was wrong");
  tree = AUTORELEASE([iCalTree new]);
  while ((el = [enumerator nextObject]))
    [tree add:el];
  ical = [tree iCalTreeAsString];

  if ([types containsObject:NSFilenamesPboardType]) {
    fw = [[NSFileWrapper alloc] initRegularFileWithContents:[ical dataUsingEncoding:NSUTF8StringEncoding]];
    if (!fw) {
      NSLog(@"Unable to encode into NSFileWrapper");
      return NO;
    }
    filename = [NSString stringWithFormat:@"%@/%@.ics", NSTemporaryDirectory(), [[selectionManager lastObject] summary]];
    written = [fw writeToFile:filename atomically:YES updateFilenames:YES];
    [fw release];
    if (!written) {
      NSLog(@"Unable to write to file %@", filename);
      return NO;
    }
    [pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
    return [pboard setPropertyList:[NSArray arrayWithObject:filename] forType:NSFilenamesPboardType];
  }
  if ([types containsObject:NSStringPboardType]) {
    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    return [pboard setString:ical forType:NSStringPboardType];
  }
  return NO;
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
  if (item == nil)
    return YES;
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
  NSString *tabIdentifier = [[tabs selectedTabViewItem] identifier];
  Date *date;

  if (object && [object isKindOfClass:[Event class]]) {
    date = [[item valueForKey:@"date"] copy];
    [date setIsDate:YES];
    [calendar setDate:date];
    [date release];
    if (![tabIdentifier isEqualToString:@"Day"] && ![tabIdentifier isEqualToString:@"Week"])
      [tabs selectTabViewItemWithIdentifier:@"Day"];
    [selectionManager set:object];
    return YES;
  }
  if (object && [object isKindOfClass:[Task class]]) {
    if (![tabIdentifier isEqualToString:@"Tasks"])
      [tabs selectTabViewItemWithIdentifier:@"Tasks"];
    [selectionManager set:object];
    return YES;
  }
  return NO;
}
@end

@implementation AppController(CalendarViewDelegate)
- (void)calendarView:(CalendarView *)cs selectedDateChanged:(Date *)date
{
  NSTabViewItem *dayTab = [tabs tabViewItemAtIndex:[tabs indexOfTabViewItemWithIdentifier:@"Day"]];
  NSTabViewItem *weekTab = [tabs tabViewItemAtIndex:[tabs indexOfTabViewItemWithIdentifier:@"Week"]];

  ASSIGNCOPY(_selectedDay, date);
  [dayView reloadData];
  [weekView reloadData];
  [dayTab setLabel:[[_selectedDay calendarDate] descriptionWithCalendarFormat:@"%e %b"]];
  [weekTab setLabel:[NSString stringWithFormat:_(@"Week %d"), [_selectedDay weekOfYear]]];
  if ([tabs selectedTabViewItem] != dayTab && [tabs selectedTabViewItem] != weekTab)
    [tabs selectTabViewItem:dayTab];
  [tabs setNeedsDisplay:YES];
  /* [[NSApp mainWindow] setTitle:[NSString stringWithFormat:@"SimpleAgenda - %@", [calendar dateAsString]]]; */
}
- (void)calendarView:(CalendarView *)cs currentDateChanged:(Date *)date
{
  [self updateSummaryData];
}
- (void)calendarView:(CalendarView *)cs userActionForDate:(Date *)date
{
  [self addAppointment:self];
}
@end

@implementation AppController(AppointmentViewDelegate)
- (void)viewEditEvent:(Event *)event;
{
  [AppointmentEditor editorForEvent:event];
}
- (void)viewModifyEvent:(Event *)event
{
  [[event store] update:event];
}
- (void)viewCreateEventFrom:(int)start to:(int)end
{
  Date *date = [[calendar date] copy];
  [date setIsDate:NO];
  [date setMinute:start];
  Event *apt = [[Event alloc] initWithStartDate:date 
			               duration:end - start 
			                  title:_(@"edit title...")];
  if (apt)
    [AppointmentEditor editorForEvent:apt];
  [date release];
  [apt release];
}
- (void)viewSelectEvent:(Event *)event
{
}
- (void)viewSelectDate:(Date *)date
{
  [calendar setDate:date];
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
    [selectionManager set:[[_sm allTasks] objectAtIndex:index]];
}
@end
