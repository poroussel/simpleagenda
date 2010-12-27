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
#import "defines.h"

@interface AppIcon : NSView <ConfigListener>
{
  ConfigManager *_cm;
  NSDictionary *_attrs;
  NSTimer *_timer;
  BOOL _showDate;
  BOOL _showTime;
  NSImage *_bell;
}
@end
@implementation AppIcon
- (void)setup
{
  _showDate = [[_cm objectForKey:APPICON_DATE] boolValue];
  _showTime = [[_cm objectForKey:APPICON_TIME] boolValue];
  if (_showTime) {
    if (_timer == nil)
      _timer = [NSTimer scheduledTimerWithTimeInterval:1
						target:self
					      selector:@selector(secondChanged:)
					      userInfo:nil
					       repeats:YES];
  } else {
    [_timer invalidate];
    _timer = nil;
  }
  [self setNeedsDisplay:YES];
}
- (void)dealloc
{
  [_cm unregisterClient:self];
  [_attrs release];
  [_timer invalidate];
  [super dealloc];
}
- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    _attrs = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont systemFontOfSize:8],NSFontAttributeName,nil];
    _bell = [NSImage imageNamed:@"bell"];
    _cm = [ConfigManager globalConfig];
    [_cm registerClient:self forKey:APPICON_DATE];
    [_cm registerClient:self forKey:APPICON_TIME];
    [self setup];
  }
  return self;
}
- (void)config:(ConfigManager *)config dataDidChangedForKey:(NSString *)key
{
  [self setup];
}
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}
- (void)secondChanged:(NSTimer *)timer
{
  [self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)rect
{
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  NSCalendarDate *now = [[Date now] calendarDate];
  NSString *aString;

  if (_showDate) {
    aString = [now descriptionWithCalendarFormat:[def objectForKey:NSShortDateFormatString]];
    [aString drawAtPoint:NSMakePoint(8, 3) withAttributes:_attrs];
  }
  if (_showTime) {
    aString = [now descriptionWithCalendarFormat:[def objectForKey:NSTimeFormatString]];
    [aString drawAtPoint:NSMakePoint(11, 49) withAttributes:_attrs];
  }
  //[_bell dissolveToPoint:NSMakePoint(35, 35) fraction:1.0];
}
- (void)mouseDown:(NSEvent *)theEvent
{
  if ([theEvent clickCount] > 1) {
    [NSApp unhide:self];
  } else {
    /* Code copied from Switcher in GAP */
    NSPoint lastLocation;
    NSPoint location;
    unsigned eventMask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSPeriodicMask | NSOtherMouseUpMask | NSRightMouseUpMask;
    NSDate *theDistantFuture = [NSDate distantFuture];
    BOOL done = NO;

    lastLocation = [theEvent locationInWindow];
    [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.02];

    while (!done) {
      theEvent = [NSApp nextEventMatchingMask: eventMask
				    untilDate: theDistantFuture
				       inMode: NSEventTrackingRunLoopMode
				      dequeue: YES];
      switch ([theEvent type]) {
      case NSRightMouseUp:
      case NSOtherMouseUp:
      case NSLeftMouseUp:
	done = YES;
	break;
      case NSPeriodic:
	location = [_window mouseLocationOutsideOfEventStream];
	if (NSEqualPoints(location, lastLocation) == NO) {
	  NSPoint origin = [_window frame].origin;	  
	  origin.x += (location.x - lastLocation.x);
	  origin.y += (location.y - lastLocation.y);
	  [_window setFrameOrigin: origin];
	}
	break;
      default:
	break;
      }
    }
    [NSEvent stopPeriodicEvents];
  }
}
@end

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

- (void)setWindowTitle
{
  NSTabViewItem *dayTab = [tabs tabViewItemAtIndex:[tabs indexOfTabViewItemWithIdentifier:@"Day"]];
  NSTabViewItem *weekTab = [tabs tabViewItemAtIndex:[tabs indexOfTabViewItemWithIdentifier:@"Week"]];

  if ([tabs selectedTabViewItem] == dayTab)
    [window setTitle:[NSString stringWithFormat:@"SimpleAgenda - %@", [calendar dateAsString]]];
  else if ([tabs selectedTabViewItem] == weekTab)
    [window setTitle:[@"SimpleAgenda - " stringByAppendingString:[NSString stringWithFormat:_(@"Week %d"), [_selectedDay weekOfYear]]]];
  else
    [window setTitle:[@"SimpleAgenda - " stringByAppendingString:_(@"Tasks")]];
}

- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithBool:YES], [NSNumber numberWithBool:YES], [NSNumber numberWithBool:NO], nil]
		       forKeys:[NSArray arrayWithObjects:APPICON_DATE, APPICON_TIME, TOOLTIP, nil]];
}

- (id)init
{
  self = [super init];
  if (self) {
    [[ConfigManager globalConfig] registerDefaults:[self defaults]];
    _selm = [SelectionManager globalManager];
    _sm = [StoreManager globalManager];
    _pc = [PreferencesController new];
    [self initSummary];
  }
  return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
  NSPopUpButtonCell *cell = [NSPopUpButtonCell new];
  [cell addItemsWithTitles:[Task stateNamesArray]];
  [[taskView tableColumnWithIdentifier:@"state"] setDataCell:cell];
  [[taskView tableColumnWithIdentifier:@"state"] setMaxWidth:128];
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
  [taskView setTarget:self];
  [taskView setDoubleAction:@selector(editAppointment:)];
  [summary sizeLastColumnToFit];
  [summary setTarget:self];
  [summary setDoubleAction:@selector(editAppointment:)];
  [window setFrameAutosaveName:@"mainWindow"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)not
{
  NSWindow *win;
  unsigned int width, height;

  win = [NSApp iconWindow];
  width = [[win contentView] bounds].size.width;
  height = [[win contentView] bounds].size.height;  
  _appicon = [[AppIcon alloc] initWithFrame: NSMakeRect(1, 1, width - 2, height - 2)];
  [[win contentView] addSubview:_appicon];

  [self registerForServices];
  [NSApp setServicesProvider: self];
  /*
   * We should register these notifications before allocating
   * the StoreManager to get all data updates. To avoid
   * numerous invisible updates which would slow the startup,
   * register only when the application is ready.
   */
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataChanged:) name:SADataChangedInStoreManager object:nil];
  /* FIXME : this is overkill, we should only refresh the views for visual changes */
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataChanged:) name:SAStatusChangedForStore object:nil];
  /* Set the selected day : this will update all views and titles (but not the summary */
  [calendar setDate:[Date today]];
  /*
   * If stores are loaded before this is executed (it happens
   * when the gui is super slow, with remote X for example)
   * we miss the dataChanged notification (that's the purpose 
   * of late registering after all) and the summary will be
   * empty so this is needed here.
   */
  [self updateSummaryData];
  /* This will init the alarms for all loaded elements needing one */
  [AlarmManager globalManager];
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_summaryRoot release];
  [_pc release];
  [_appicon release];
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
  NSEnumerator *enumerator = [[_sm scheduledAppointmentsForDay:_selectedDay] objectEnumerator];
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
  id lastSelection = [_selm lastObject];

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
  NSEnumerator *enumerator = [_selm enumerator];
  Element *el;

  while ((el = [enumerator nextObject]))
    [[el store] remove:el];
  [_selm clear];
}

- (void)exportAppointment:(id)sender;
{
  NSEnumerator *enumerator = [_selm enumerator];
  NSSavePanel *panel = [NSSavePanel savePanel];
  NSString *str;
  iCalTree *tree;
  Element *el;

  if ([_selm count] > 0) {
    [panel setRequiredFileType:@"ics"];
    [panel setTitle:_(@"Export as")];
    if ([panel runModalForDirectory:nil file:[[_selm lastObject] summary]] == NSOKButton) {
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
  [_selm copySelection];
}

- (void)cut:(id)sender
{
  [_selm cutSelection];
}

- (void)paste:(id)sender
{
  if ([_selm copiedCount] > 0) {
    NSEnumerator *enumerator = [[_selm paste] objectEnumerator];
    Date *date = [[calendar date] copy];
    Event *el;
    id <MemoryStore> store;
    int start;

    [date setIsDate:NO];
    while ((el = [enumerator nextObject])) {
      /* FIXME : store property could be handled by Event:copy ? */
      store = [el store];

      /* FIXME : this isn't enough : we have to find a writable store or error out */
      if (![store writable])
	store = [_sm defaultStore];
	
      start = [[el startDate] minuteOfDay];
      if ([_selm lastOperation] == SMCopy)
	el = [el copy];
      [date setMinute:start];
      [el setStartDate:date];
      if ([_selm lastOperation] == SMCopy) {
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
  NSEnumerator *enumerator;
  Element *el;

  if (sel_isEqual(action, @selector(copy:)))
    return [_selm count] > 0;
  if (sel_isEqual(action, @selector(cut:))) {
    if ([_selm count] == 0)
      return NO;
    enumerator = [[_selm selection] objectEnumerator];
    while ((el = [enumerator nextObject])) {
      if (![[el store] writable])
	return NO;
    }
    return YES;
  }
  if (sel_isEqual(action, @selector(editAppointment:)))
    return [_selm count] == 1;
  if (sel_isEqual(action, @selector(delAppointment:)))
    return [_selm count] > 0;
  if (sel_isEqual(action, @selector(exportAppointment:)))
    return [_selm count] > 0;
  if (sel_isEqual(action, @selector(paste:)))
    return [_selm copiedCount] > 0;
  return YES;
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
  if ([_selm count] && (!sendType || [sendType isEqual:NSFilenamesPboardType] || [sendType isEqual:NSStringPboardType]))
    return self;
  return nil;
}
- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
  NSEnumerator *enumerator = [_selm enumerator];
  Element *el;
  NSString *ical;
  NSString *filename;
  iCalTree *tree;
  NSFileWrapper *fw;
  BOOL written;

  if ([_selm count] == 0)
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
    filename = [NSString stringWithFormat:@"%@/%@.ics", NSTemporaryDirectory(), [[_selm lastObject] summary]];
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
    [_selm set:object];
    return YES;
  }
  if (object && [object isKindOfClass:[Task class]]) {
    if (![tabIdentifier isEqualToString:@"Tasks"])
      [tabs selectTabViewItemWithIdentifier:@"Tasks"];
    [_selm set:object];
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
  NSTabViewItem *taskTab = [tabs tabViewItemAtIndex:[tabs indexOfTabViewItemWithIdentifier:@"Tasks"]];

  ASSIGNCOPY(_selectedDay, date);
  [dayView setDate:date];
  [weekView setDate:date];
  /* Hack to enable translation of this tab's label */
  [taskTab setLabel:_(@"Tasks")];
  [dayTab setLabel:[[_selectedDay calendarDate] descriptionWithCalendarFormat:@"%e %b"]];
  [weekTab setLabel:[NSString stringWithFormat:_(@"Week %d"), [_selectedDay weekOfYear]]];
  if ([tabs selectedTabViewItem] != dayTab && [tabs selectedTabViewItem] != weekTab)
    [tabs selectTabViewItem:dayTab];
  [tabs setNeedsDisplay:YES];
  [self setWindowTitle];
}
- (void)calendarView:(CalendarView *)cs currentDateChanged:(Date *)date
{
  [self updateSummaryData];
  [_appicon setNeedsDisplay:YES];
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
    [_selm set:[[_sm allTasks] objectAtIndex:index]];
}
@end

@implementation AppController(NSTabViewDelegate)
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  [self setWindowTitle];
}
@end
