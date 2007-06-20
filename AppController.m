/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "LocalStore.h"
#import "AppointmentEditor.h"
#import "StoreManager.h"
#import "AppointmentCache.h"
#import "AppController.h"
#import "Event.h"
#import "PreferencesController.h"
#import "UserDefaults.h"
#import "defines.h"

NSComparisonResult sortAppointments(Event *a, Event *b, void *data)
{
  return [[a startDate] compare:[b startDate]];
}

@implementation AppController

- (NSDictionary *)defaults
{
  NSDictionary *dict = [NSDictionary 
			 dictionaryWithObjects:[NSArray arrayWithObjects:@"9", @"18", @"15", nil]
			 forKeys:[NSArray arrayWithObjects:FIRST_HOUR, LAST_HOUR, MIN_STEP, nil]];
  return dict;
}

- (id)init
{
  Date *date;

  self = [super init];
  if (self) {
    _defaults = [UserDefaults sharedInstance];
    [_defaults setHardDefaults:[self defaults]];
    [_defaults registerClient:self forKey:FIRST_HOUR];
    [_defaults registerClient:self forKey:LAST_HOUR];
    [_defaults registerClient:self forKey:MIN_STEP];
    _editor = [AppointmentEditor new];
    _sm = [StoreManager new];
    _pc = [[PreferencesController alloc] initWithStoreManager:_sm];

    date = [Date new];
    _current = [[AppointmentCache alloc] initwithStoreManager:_sm from:date to:date];
    [_current setDelegate:self];
    _today = [[AppointmentCache alloc] initwithStoreManager:_sm from:date to:date];
    [_today setTitle:@"Today"];
    [date incrementDay];
    _tomorrow = [[AppointmentCache alloc] initwithStoreManager:_sm from:date to:date];
    [_tomorrow setTitle:@"Tomorrow"];
    [date release];
  }
  return self;
}

- (void)defaultDidChanged:(NSString *)name
{
  [dayView reloadData];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
  [dayView reloadData];
  [summary sizeToFit];
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
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
  [_defaults unregisterClient:self];
  [_defaults release];
}

- (void)showPrefPanel:(id)sender
{
  [_pc showPreferences];
}

- (int)_sensibleStartForDuration:(int)duration
{
  int minute = [self firstHourForDayView] * 60;
  NSArray *sorted = [[_current array] sortedArrayUsingFunction:sortAppointments context:nil];
  NSEnumerator *enumerator = [sorted objectEnumerator];
  Event *apt;

  while ((apt = [enumerator nextObject])) {
    if (minute + duration <= [[apt startDate] minuteOfDay])
      return minute;
    minute = [[apt startDate] minuteOfDay] + [apt duration];
  }
  if (minute < [self lastHourForDayView] * 60)
    return minute;
  return [self firstHourForDayView] * 60;
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
    [[apt store] delAppointment: apt];
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
      [_selection setStartDate:date andConstrain:NO];
      [[_selection store] updateAppointment:_selection];
    } else {
      Event *new = [_selection copy];
      [date setMinute:[self _sensibleStartForDuration:[new duration]]];
      [new setStartDate:date andConstrain:NO];
      [[_selection store] addAppointment:new];
      [new release];
    }
    [date release];
  }
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  SEL action = [menuItem action];
  if (action == @selector(copy:) || action == @selector(cut:) ||
      action == @selector(editAppointment:) || action == @selector(delAppointment:))
    return [dayView selectedAppointment] != nil;
  if (action == @selector(paste:))
    return _selection != nil;
  return YES;
}


/* DayViewDataSource protocol */

- (int)firstHourForDayView
{
  return [_defaults integerForKey:FIRST_HOUR];
}

- (int)lastHourForDayView
{
  return [_defaults integerForKey:LAST_HOUR];
}

- (int)minimumStepForDayView
{
  return [_defaults integerForKey:MIN_STEP];
}

- (NSEnumerator *)scheduledAppointmentsForDayView
{
  return [_current enumerator];
}

@end

@implementation AppController(NSOutlineViewDataSource)

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
  if (item == nil)
    return 2;
  if ([item class] == [AppointmentCache class])
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
    return _tomorrow;
  }
  return [[item array] objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
  if ([@"title" isEqual:[tableColumn identifier]])
    return [item title];
  if ([item respondsToSelector:@selector(startDate)])
    return [[item startDate] description];
  return [NSString stringWithFormat:@"%d item(s)", [item count]];
}

@end

@implementation AppController(CalendarView)

- (void)calendarView:(CalendarView *)cs selectedDateChanged:(Date *)date;
{
  [_current setFrom:date to:date];
  [dayView reloadData];
}

- (void)calendarView:(CalendarView *)cs currentDateChanged:(Date *)date;
{
  [_today setFrom:date to:date];
  [date incrementDay];
  [_tomorrow setFrom:date to:date];
  [summary reloadData];
}

@end

@implementation AppController(DayViewDelegate)

- (void)doubleClickOnAppointment:(Event *)apt
{
  /*
   * FIXME : we should allow to view appointment's 
   * details even if it's read only
   */
  if ([[apt store] isWritable])
    [self _editAppointment:apt];
}

- (void)modifyAppointment:(Event *)apt
{
  [[apt store] updateAppointment:apt];
}

- (void)createAppointmentFrom:(int)start to:(int)end
{
  Date *date = [[calendar date] copy];
  [date setMinute:start];
  Event *apt = [[Event alloc] initWithStartDate:date 
			      duration:end - start 
			      title:@"edit title..."];
  if (apt && [_editor editAppointment:apt withStoreManager:_sm]) {
    [dayView reloadData];
    [summary reloadData];
  }
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
