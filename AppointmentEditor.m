/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "HourFormatter.h"
#import "AgendaStore.h"

@implementation AppointmentEditor
-(id)init
{
  HourFormatter *formatter;
  NSDateFormatter *dateFormatter;

  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Appointment" owner:self])
      return nil;
    /* FIXME : shouldn't be needed but Gorm just won't set it */
    [duration setContinuous:YES];
    formatter = [[[HourFormatter alloc] init] autorelease];
    dateFormatter = [[[NSDateFormatter alloc] initWithDateFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortDateFormatString] allowNaturalLanguage:NO] autorelease];
    [durationText setFormatter:formatter];
    [endDate setFormatter:dateFormatter];
    [endDate setObjectValue:[NSDate date]];
  }
  return self;
}

-(BOOL)editAppointment:(Event *)data withStoreManager:(StoreManager *)sm
{
  NSEnumerator *list = [sm storeEnumerator];
  id <MemoryStore> aStore;
  id <MemoryStore> originalStore;
  int ret;

  [title setStringValue:[data summary]];
  [duration setFloatValue:[data duration] / 60.0];
  [durationText setFloatValue:[data duration] / 60.0];
  [repeat selectItemAtIndex:[data interval]];
  [endDate setEnabled:([data interval] != 0)];
  [location setStringValue:[data location]];
  [allDay setState:[data allDay]];

  [[description textStorage] deleteCharactersInRange:NSMakeRange(0, [[description textStorage] length])];
  [[description textStorage] appendAttributedString:[data text]];

  [window makeFirstResponder:title];

  originalStore = [data store];
  if (!originalStore)
    [data setStore:[sm defaultStore]];
  else if (![originalStore writable])
    [ok setEnabled:NO];
    
  [store removeAllItems];
  while ((aStore = [list nextObject])) {
    if ([aStore writable] || aStore == originalStore)
      [store addItemWithTitle:[aStore description]];
  }
  [store selectItemWithTitle:[[data store] description]];
  startDate = [data startDate];
  ret = [NSApp runModalForWindow:window];
  [window close];
  if (ret == NSOKButton) {
    [data setSummary:[title stringValue]];
    [data setDuration:[duration floatValue] * 60.0];
    [data setInterval:[repeat indexOfSelectedItem]];
    if ([repeat indexOfSelectedItem] != 0) {
      /* FIXME : don't force 10 years validity for recurrent events */
      Date *end = [[data startDate] copy];
      [end changeYearBy:10];
      [data setEndDate:end];
      [data setFrequency:1];
      [end release];
    }
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

-(void)validate:(id)sender
{
  [NSApp stopModalWithCode: NSOKButton];
}

-(void)cancel:(id)sender
{
  [NSApp stopModalWithCode: NSCancelButton];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  id end = [endDate objectValue];

  if (end == nil || ![end isKindOfClass:[NSDate class]])
    [ok setEnabled:NO];
  else {
    [ok setEnabled:YES];
  }
}

- (void)selectFrequency:(id)sender
{
  Date *futur = [startDate copy];
  int selected = [repeat indexOfSelectedItem];

  [endDate setEnabled:(selected != 0)];
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
}
@end
