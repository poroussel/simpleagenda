/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "TaskEditor.h"
#import "StoreManager.h"
#import "Task.h"

static NSMutableDictionary *editors;

@implementation TaskEditor
- (id)init
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Task" owner:self])
      return nil;
  }
  return self;
}

- (id)initWithTask:(Task *)task
{
  StoreManager *sm = [StoreManager globalManager];
  NSEnumerator *list = [sm storeEnumerator];
  id <MemoryStore> aStore;
  id <MemoryStore> originalStore;

  self = [self init];
  if (self) {
    ASSIGN(_task, task);
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
    [window makeKeyAndOrderFront:self];
  }
  return self;
}

- (void)dealloc 
{ 
  RELEASE(_task); 
  [super dealloc]; 
} 

+ (void)initialize
{
  editors = [[NSMutableDictionary alloc] initWithCapacity:2];
}

+ (TaskEditor *)editorForTask:(Task *)task
{
  TaskEditor *editor;

  if ((editor = [editors objectForKey:[task UID]])) {
    [editor->window makeKeyAndOrderFront:self];
    return editor;
  }
  editor = [[TaskEditor alloc] initWithTask:task];
  [editors setObject:editor forKey:[task UID]];
  return AUTORELEASE(editor);
}

- (void)validate:(id)sender
{
  StoreManager *sm = [StoreManager globalManager];
  id <MemoryStore> originalStore = [_task store];
  id <MemoryStore> aStore;

  [_task setSummary:[summary stringValue]];
  [_task setText:[[description textStorage] copy]];
  [_task setState:[state indexOfSelectedItem]];
  aStore = [sm storeForName:[store titleOfSelectedItem]];
  if (!originalStore)
    [aStore add:_task];
  else if (originalStore == aStore)
    [aStore update:_task];
  else {
    [originalStore remove:_task];
    [aStore add:_task];
  }
  [editors removeObjectForKey:[_task UID]];
  [window close];
}
- (void)cancel:(id)sender
{
  [editors removeObjectForKey:[_task UID]]; 
  [window close]; 
}
@end
