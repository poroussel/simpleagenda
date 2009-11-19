/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "TaskEditor.h"
#import "StoreManager.h"
#import "Task.h"

@implementation TaskEditor
-(id)init
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Task" owner:self])
      return nil;
  }
  return self;
}

-(BOOL)editTask:(Task *)task
{
  StoreManager *sm = [StoreManager globalManager];
  NSEnumerator *list = [sm storeEnumerator];
  id <MemoryStore> aStore;
  id <MemoryStore> originalStore;
  int ret;

  [summary setStringValue:[task summary]];

  [[description textStorage] deleteCharactersInRange:NSMakeRange(0, [[description textStorage] length])];
  [[description textStorage] appendAttributedString:[task text]];

  [window makeFirstResponder:summary];

  originalStore = [task store];
  if (!originalStore)
    [task setStore:[sm defaultStore]];
  else if (![originalStore writable])
    [ok setEnabled:NO];
    
  [store removeAllItems];
  while ((aStore = [list nextObject])) {
    if ([aStore writable] || aStore == originalStore)
      [store addItemWithTitle:[aStore description]];
  }
  [store selectItemWithTitle:[[task store] description]];

  [state removeAllItems];
  [state addItemsWithTitles:[Task stateNamesArray]];
  [state selectItemWithTitle:[task stateAsString]];

  ret = [NSApp runModalForWindow:window];
  [window close];
  if (ret == NSOKButton) {
    [task setSummary:[summary stringValue]];
    [task setText:[[description textStorage] copy]];
    [task setState:[state indexOfSelectedItem]];
    aStore = [sm storeForName:[store titleOfSelectedItem]];
    if (!originalStore)
      [aStore add:task];
    else if (originalStore == aStore)
      [aStore update:task];
    else {
      [originalStore remove:task];
      [aStore add:task];
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
