/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "HourFormatter.h"
#import "AgendaStore.h"
#import "ConfigManager.h"
#import "AlarmEditor.h"
#import "defines.h"

static NSMutableDictionary *editors;

@implementation AppointmentEditor
- (BOOL)canBeModified
{
  id <MemoryStore> selectedStore = [[StoreManager globalManager] storeForName:[store titleOfSelectedItem]];
  return [selectedStore enabled] && [selectedStore writable];
}

- (id)init
{
  HourFormatter *formatter;
  NSDateFormatter *dateFormatter;

  if (![NSBundle loadNibNamed:@"Appointment" owner:self]) {
    NSLog(@"Unable to load Appointment.gorm");
    return nil;
  }
  self = [super init];
  if (self) {
    formatter = AUTORELEASE([[HourFormatter alloc] init]);
    dateFormatter = AUTORELEASE([[NSDateFormatter alloc] initWithDateFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortDateFormatString] allowNaturalLanguage:NO]);
    [durationText setFormatter:formatter];
    [timeText setFormatter:formatter];
    [endDate setFormatter:dateFormatter];
    [endDate setObjectValue:[NSDate date]];
  }
  return self;
}

- (id)document
{
   return nil;
}

- (id)initWithEvent:(Event *)event
{
  StoreManager *sm = [StoreManager globalManager];
  NSEnumerator *list = [sm storeEnumerator];
  id <MemoryStore> aStore;
  id <MemoryStore> originalStore;

  self = [self init];
  if (self) {
    ASSIGN(_event , event);
    ASSIGNCOPY(_modifiedAlarms, [event alarms]);
    [title setStringValue:[event summary]];
    [duration setIntValue:[event duration] * 60];
    [durationText setIntValue:[event duration] * 60];
    [location setStringValue:[event location]];
    [allDay setState:[event allDay]];
    [time setIntValue:[[event startDate] minuteOfDay] * 60];
    [timeText setIntValue:[[event startDate] minuteOfDay] * 60];
    if (![event rrule])
      [repeat selectItemAtIndex:0];
    else
      [repeat selectItemAtIndex:[[event rrule] frequency] - 2];

    [[description textStorage] deleteCharactersInRange:NSMakeRange(0, [[description textStorage] length])];
    [[description textStorage] appendAttributedString:[event text]];

    [window makeFirstResponder:title];

    originalStore = [event store];
    [store removeAllItems];
    while ((aStore = [list nextObject])) {
      if ([aStore enabled] && ([aStore writable] || aStore == originalStore))
	[store addItemWithTitle:[aStore description]];
    }
    if ([event store])
      [store selectItemWithTitle:[[event store] description]];
    else
      [store selectItemWithTitle:[[sm defaultStore] description]];
    startDate = [event startDate];

    [until setEnabled:([event rrule] != nil)];
    if ([event rrule] && [[event rrule] until]) {
      [until setState:YES];
      [endDate setObjectValue:[[[event rrule] until] calendarDate]];
    } else {
      [until setState:NO];
      [endDate setObjectValue:nil];
    }
    [endDate setEnabled:[until state]];
    [ok setEnabled:[self canBeModified]];
    [window makeKeyAndOrderFront:self];
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_event);
  RELEASE(_modifiedAlarms);
  [super dealloc];
}

+ (void)initialize
{
  editors = [[NSMutableDictionary alloc] initWithCapacity:2];
}

+ (AppointmentEditor *)editorForEvent:(Event *)event
{
  AppointmentEditor *editor;

  if ((editor = [editors objectForKey:[event UID]])) {
    [editor->window makeKeyAndOrderFront:self];
    return editor;
  }
  editor = [[AppointmentEditor alloc] initWithEvent:event];
  [editors setObject:editor forKey:[event UID]];
  return AUTORELEASE(editor);
}

- (void)validate:(id)sender
{
  StoreManager *sm = [StoreManager globalManager];
  id <MemoryStore> aStore;
  Date *date;

  [_event setSummary:[title stringValue]];
  [_event setDuration:[duration intValue] / 60];

  if (![repeat indexOfSelectedItem]) {
    [_event setRRule:nil];
  } else {
    RecurrenceRule *rule;
    if ([until state] && [endDate objectValue])
      rule = [[RecurrenceRule alloc] initWithFrequency:[repeat indexOfSelectedItem]+2 until:[Date dateWithCalendarDate:[endDate objectValue] withTime:NO]];
    else
      rule = [[RecurrenceRule alloc] initWithFrequency:[repeat indexOfSelectedItem]+2];
    [_event setRRule:AUTORELEASE(rule)];
  }
  [_event setText:[description textStorage]];
  [_event setLocation:[location stringValue]];
  [_event setAllDay:[allDay state]];
  if (![_event allDay]) {
    date = [[_event startDate] copy];
    [date setIsDate:NO];
    [date setMinute:[time intValue] / 60];
    [_event setStartDate:date];
    [date release];
  }
  [_event setAlarms:_modifiedAlarms];
  aStore = [sm storeForName:[store titleOfSelectedItem]];
  [sm moveElement:_event toStore:aStore];
  [window close];
  [editors removeObjectForKey:[_event UID]];
  /* After this point the panel instance is released */
}

- (void)cancel:(id)sender
{
  [window close];
  [editors removeObjectForKey:[_event UID]];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  id end = [endDate objectValue];
  [ok setEnabled: ([self canBeModified] && (end != nil))];
}

- (void)selectFrequency:(id)sender
{
  int index = [repeat indexOfSelectedItem];
  [until setEnabled:!!index];
  if (!index)
    [until setState:NO];
  [self toggleUntil:nil];
}

- (void)toggleUntil:(id)sender
{
  [endDate setEnabled:[until state]];
  if ([until state]) {
    Date *futur = [startDate copy];
    int selected = [repeat indexOfSelectedItem];
    switch (selected) {
    case 1:
    case 2:
      /* Daily and weekly : 1 month by default */
      [futur changeDayBy:[futur numberOfDaysInMonth]];
      break;
    case 3:
      /* Monthly : 1 year */
      [futur changeYearBy:1];
      break;
    case 4:
      /* Yearly : 10 years */
      [futur changeYearBy:10];
      break;
    }
    [endDate setObjectValue:[futur calendarDate]];
    [futur release];
  } else
    [endDate setObjectValue:nil];
}

- (void)toggleAllDay:(id)sender
{
  if ([allDay state]) {
    [duration setEnabled:NO];
    [duration setFloatValue:0];
    [durationText setFloatValue:0];
    [time setEnabled:NO];
    [time setFloatValue:0];
    [timeText setFloatValue:0];
  } else {
    [duration setEnabled:YES];
    [duration setFloatValue:1];
    [durationText setFloatValue:1];
    [time setEnabled:YES];
    [time setFloatValue:[[ConfigManager globalConfig] integerForKey:FIRST_HOUR]];
    [timeText setFloatValue:[[ConfigManager globalConfig] integerForKey:FIRST_HOUR]];
  }
}

- (void)editAlarms:(id)sender
{
  NSArray *alarms;

  alarms = [AlarmEditor editAlarms:_modifiedAlarms];
  if (alarms)
    ASSIGN(_modifiedAlarms, alarms);
  [window makeKeyAndOrderFront:self];
}

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
  if ([NSStringFromSelector(aSelector) isEqualToString:@"insertTab:"]) {
    [[description window] selectNextKeyView:self];
    return YES;
  }
  return [description tryToPerform:aSelector with:aTextView];
}
@end
