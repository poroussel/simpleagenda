/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "HourFormatter.h"
#import "AgendaStore.h"
#import "ConfigManager.h"
#import "defines.h"

@implementation AppointmentEditor
- (id)init
{
  HourFormatter *formatter;
  NSDateFormatter *dateFormatter;

  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Appointment" owner:self])
      return nil;
    formatter = [[[HourFormatter alloc] init] autorelease];
    dateFormatter = [[[NSDateFormatter alloc] initWithDateFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortDateFormatString] allowNaturalLanguage:NO] autorelease];
    [durationText setFormatter:formatter];
    [endDate setFormatter:dateFormatter];
    [endDate setObjectValue:[NSDate date]];
  }
  return self;
}

- (BOOL)canBeModified
{
  id <MemoryStore> selectedStore = [[StoreManager globalManager] storeForName:[store titleOfSelectedItem]];
  return [selectedStore enabled] && [selectedStore writable];
}

- (BOOL)editAppointment:(Event *)data
{
  StoreManager *sm = [StoreManager globalManager];
  NSEnumerator *list = [sm storeEnumerator];
  id <MemoryStore> aStore;
  id <MemoryStore> originalStore;
  int ret;

  [title setStringValue:[data summary]];
  [duration setFloatValue:[data duration] / 60.0];
  [durationText setFloatValue:[data duration] / 60.0];
  [location setStringValue:[data location]];
  [allDay setState:[data allDay]];
  if (![data rrule])
    [repeat selectItemAtIndex:0];
  else
    [repeat selectItemAtIndex:[[data rrule] frequency] - 2];

  [[description textStorage] deleteCharactersInRange:NSMakeRange(0, [[description textStorage] length])];
  [[description textStorage] appendAttributedString:[data text]];

  [window makeFirstResponder:title];

  originalStore = [data store];
  if (!originalStore)
    [data setStore:[sm defaultStore]];
    
  [store removeAllItems];
  while ((aStore = [list nextObject])) {
    if ([aStore writable] || aStore == originalStore)
      [store addItemWithTitle:[aStore description]];
  }
  [store selectItemWithTitle:[[data store] description]];
  startDate = [data startDate];

  [until setEnabled:([data rrule] != nil)];
  if ([data rrule] && [[data rrule] until]) {
    [until setState:YES];
    [endDate setObjectValue:[[[data rrule] until] calendarDate]];
  } else {
    [until setState:NO];
    [endDate setObjectValue:nil];
  }
  [endDate setEnabled:[until state]];

  [ok setEnabled:[self canBeModified]];
  ret = [NSApp runModalForWindow:window];
  [window close];
  if (ret == NSOKButton) {
    [data setSummary:[title stringValue]];
    [data setDuration:[duration floatValue] * 60.0];

    if (![repeat indexOfSelectedItem]) {
      [data setRRule:nil];
    } else {
      RecurrenceRule *rule;
      if ([until state] && [endDate objectValue])
	rule = [[RecurrenceRule alloc] initWithFrequency:[repeat indexOfSelectedItem]+2 until:[Date dateWithCalendarDate:[endDate objectValue] withTime:NO]];
      else
	rule = [[RecurrenceRule alloc] initWithFrequency:[repeat indexOfSelectedItem]+2];
      [data setRRule:AUTORELEASE(rule)];
    }
    /* FIXME : why do we copy one and not the other ? */
    [data setText:[[description textStorage] copy]];
    [data setLocation:[location stringValue]];
    [data setAllDay:[allDay state]];

    aStore = [sm storeForName:[store titleOfSelectedItem]];
    if (!originalStore)
      [aStore add:data];
    else if (originalStore == aStore)
      [aStore update:data];
    else {
      [originalStore remove:data];
      [aStore add:data];
    }
    return YES;
  }
  return NO;
}

- (void)validate:(id)sender
{
  [NSApp stopModalWithCode: NSOKButton];
}

- (void)cancel:(id)sender
{
  [NSApp stopModalWithCode: NSCancelButton];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  id end = [endDate objectValue];

  if (end == nil || ![end isKindOfClass:[NSDate class]])
    [ok setEnabled:NO];
  else
    [ok setEnabled:[self canBeModified]];
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
    [duration setIntValue:0];
    [durationText setIntValue:0];
  } else {
    [duration setEnabled:YES];
    [duration setFloatValue:1];
    [durationText setFloatValue:1];
    [startDate setMinute:[[ConfigManager globalConfig] integerForKey:FIRST_HOUR] * 60];
  }
}
@end
