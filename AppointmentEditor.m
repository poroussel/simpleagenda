/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "HourFormatter.h"
#import "AgendaStore.h"

@implementation AppointmentEditor

-(id)init
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Appointment" owner:self])
      return nil;
    HourFormatter *formatter = [[[HourFormatter alloc] init] autorelease];
    [[durationText cell] setFormatter:formatter];
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

  ret = [NSApp runModalForWindow:window];
  [window close];
  if (ret == NSOKButton) {
    [data setSummary:[title stringValue]];
    [data setDuration:[duration floatValue] * 60.0];
    [data setInterval:[repeat indexOfSelectedItem]];
    if ([repeat indexOfSelectedItem] == 0)
      [data setEndDate:[data startDate]];
    else {
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
      [aStore addEvent:data];
    else if (originalStore == aStore)
      [aStore update:data];
    else {
      [originalStore remove:data];
      [aStore addEvent:data];
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

@end
