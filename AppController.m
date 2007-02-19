/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "LocalStore.h"
#import "AppointmentEditor.h"
#import "StoreManager.h"
#import "AppController.h"

NSComparisonResult sortAppointments(Appointment *a, Appointment *b, void *data)
{
  return [[a startDate] compare:[b startDate]];
}

@implementation AppController

- (void)initDefaults
{
  _defaults = [NSUserDefaults standardUserDefaults];

  if ([_defaults objectForKey:@"firstHour"] == nil)
    [_defaults setInteger:9 forKey:@"firstHour"];
  _firstHour = [_defaults integerForKey:@"firstHour"];

  if ([_defaults objectForKey:@"lastHour"] == nil)
    [_defaults setInteger:18 forKey:@"lastHour"];
  _lastHour = [_defaults integerForKey:@"lastHour"];

  if ([_defaults objectForKey:@"stores"] == nil) {
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"LocalStore", @"Personal", @"Personal Agenda", nil]
				       forKeys:[NSArray arrayWithObjects:@"storeClass", @"storeFilename", @"storeName", nil]];
    NSArray *array = [NSArray arrayWithObject:dict];
    [_defaults setObject:array forKey:@"stores"];
  }

  if ([_defaults objectForKey:@"defaultStore"] == nil)
    [_defaults setObject:@"Personal Agenda" forKey:@"defaultStore"];
}

- (id)init
{
  self = [super init];
  if (self) {
    [self initDefaults];
    [[NSNotificationCenter defaultCenter] addObserver:self
					  selector:@selector(userDefaultsChanged:)
					  name:@"NSUserDefaultsDidChangeNotification" object:nil];

    _sm = [[StoreManager alloc] initWithStores:[_defaults objectForKey:@"stores"]
				withDefault:[_defaults objectForKey:@"defaultStore"]];
    _cache = [[NSMutableSet alloc] initWithCapacity:16];
  }
  return self;
}

- (void)updateCache
{
  NSArray *array;
  Date *start = [[calendar date] copy];
  Date *end = [[calendar date] copy];
  NSEnumerator *enumerator;
  id <AgendaStore> store;

  [start setMinute:_firstHour * 60];
  [end setMinute:(_lastHour + 1) * 60];

  [_cache removeAllObjects];
  enumerator = [_sm objectEnumerator];
  while ((store = [enumerator nextObject])) {
    array = [store scheduledAppointmentsFrom:start to:end];
    [_cache addObjectsFromArray:array];
  }
  
  [start release];
  [end release];
  [dayView reloadData];
}

- (void)userDefaultsChanged:(NSNotification *)notification
{
  [self initDefaults];
  [self updateCache];
}

- (void)awakeFromNib
{
  editor = [AppointmentEditor new];
  [NSBundle loadNibNamed:@"Appointment" owner:editor];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
  [self updateCache];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
  [_cache release];
  [_sm release];
  [editor release];
}

- (void)showPrefPanel:(id)sender
{
}

- (int)_sensibleStartForDuration:(int)duration
{
  int minute = _firstHour * 60;
  NSArray *sorted = [[_cache allObjects] sortedArrayUsingFunction:sortAppointments context:nil];
  NSEnumerator *enumerator = [sorted objectEnumerator];
  Appointment *apt;

  while ((apt = [enumerator nextObject])) {
    if (minute + duration <= [[apt startDate] minuteOfDay])
      return minute;
    minute = [[apt startDate] minuteOfDay] + [apt duration];
  }
  if (minute < _lastHour * 60)
    return minute;
  return _firstHour * 60;
}

- (Appointment *)createEmptyAppointment
{
  Date *date = [[calendar date] copy];
  Appointment *apt = [Appointment new];
  if (apt) {
    [date setMinute:[self _sensibleStartForDuration:60]];
    [apt setDuration:60];
    [apt setStartDate:date andConstrain:NO];
    [apt setTitle:@"edit title..."];
  }
  [date release];
  return apt;
}

- (void)_editAppointment:(Appointment *)apt
{
  if ([editor editAppointment:apt]) {
    [[_sm defaultStore] updateAppointment:apt];
    [self updateCache];
  }    
}

- (void)addAppointment:(id)sender
{
  Appointment *apt = [self createEmptyAppointment];

  if ([editor editAppointment:apt]) {
    [[_sm defaultStore] addAppointment:apt];
    [self updateCache];
  }    
  [apt release];
}

- (void)editAppointment:(id)sender
{
  Appointment *apt = [dayView selectedAppointment];

  if (apt)
    [self _editAppointment:apt];
}

- (void)delAppointment:(id)sender
{
  Appointment *apt = [dayView selectedAppointment];

  if (apt) {
    [[_sm defaultStore] delAppointment: apt];
    [self updateCache];
  }
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
  if (_selection) {
    Date *date = [[calendar date] copy];
    if (_deleteSelection) {
      [date setMinute:[self _sensibleStartForDuration:[_selection duration]]];
      [_selection setStartDate:date andConstrain:NO];
      [[_sm defaultStore] updateAppointment:_selection];
    } else {
      Appointment *new = [_selection copy];
      [date setMinute:[self _sensibleStartForDuration:[new duration]]];
      [new setStartDate:date andConstrain:NO];
      [[_sm defaultStore] addAppointment:new];
    }
    [date release];
    [self updateCache];
  }
}

/* CalendarView delegate method */
- (void)dateChanged:(Date *)newDate
{
  [self updateCache];
  NSLog(@"Show data for %@ => %d apt", [newDate description], [_cache count]);
}

/* DayViewDataSource methods */
- (int)firstHourForDayView
{
  return _firstHour;
}

- (int)lastHourForDayView
{
  return _lastHour;
}

- (NSEnumerator *)scheduledAppointmentsForDayView
{
  return [_cache objectEnumerator];
}

/* DayView Delegate methods */

- (void)doubleClickOnAppointment:(Appointment *)apt
{
  [self _editAppointment:apt];
}

@end
