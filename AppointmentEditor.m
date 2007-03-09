/* emacs buffer mode hint -*- objc -*- */

#import <math.h>
#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"
#import "HourFormatter.h"
#import "AgendaStore.h"

@implementation AppointmentEditor

- (void)awakeFromNib
{
  HourFormatter *formatter = [[[HourFormatter alloc] init] autorelease];
  [[durationText cell] setFormatter:formatter];
}

-(BOOL)editAppointment:(Event *)data withStoreManager:(StoreManager *)sm
{
  NSEnumerator *list = [sm objectEnumerator];
  id <AgendaStore> aStore;
  int ret;

  [title setStringValue:[data title]];
  [duration setFloatValue:[data duration] / 60.0];
  [durationText setFloatValue:[data duration] / 60.0];
  [repeat selectItemAtIndex:[data interval]];
  [location setStringValue:[data location]];

  [[description textStorage] deleteCharactersInRange:NSMakeRange(0, [[description textStorage] length])];
  [[description textStorage] appendAttributedString:[data descriptionText]];

  [window makeFirstResponder:title];

  if (![data store])
    [data setStore:[sm defaultStore]];
  [store removeAllItems];
  while ((aStore = [list nextObject]))
    [store addItemWithTitle:[aStore description]];
  [store selectItemWithTitle:[[data store] description]];

  ret = [NSApp runModalForWindow:window];
  [window close];
  if (ret == NSOKButton) {
    Date *end = [[data startDate] copy];
    [end changeYearBy:10];
    [data setTitle:[title stringValue]];
    [data setDuration:[duration floatValue] * 60.0];
    [data setInterval:[repeat indexOfSelectedItem]];
    [data setEndDate:end];
    [data setDescriptionText:[[description textStorage] copy]];
    [data setLocation:[location stringValue]];

    aStore = [sm storeForName:[store titleOfSelectedItem]];
    /* FIXME : do something if store changed */
    if ([[data store] contains:data])
      [aStore updateAppointment:data];
    else
      [aStore addAppointment:data];
    [end release];
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
