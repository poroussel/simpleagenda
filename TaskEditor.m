/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "TaskEditor.h"
#import "StoreManager.h"
#import "Task.h"
#import "AlarmEditor.h"

static NSMutableDictionary *editors;

@implementation TaskEditor
- (BOOL)canBeModified
{
  id <MemoryStore> selectedStore = [[StoreManager globalManager] storeForName:[store titleOfSelectedItem]];
  return [selectedStore enabled] && [selectedStore writable];
}

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
    ASSIGNCOPY(_modifiedAlarms, [task alarms]);
    [summary setStringValue:[task summary]];

    [[description textStorage] deleteCharactersInRange:NSMakeRange(0, [[description textStorage] length])];
    [[description textStorage] appendAttributedString:[task text]];

    [window makeFirstResponder:summary];

    originalStore = [task store];
    [store removeAllItems];
    while ((aStore = [list nextObject])) {
      if ([aStore enabled] && ([aStore writable] || aStore == originalStore))
	[store addItemWithTitle:[aStore description]];
    }
    if ([task store])
      [store selectItemWithTitle:[[task store] description]];
    else
      [store selectItemWithTitle:[[sm defaultStore] description]];

    [state removeAllItems];
    [state addItemsWithTitles:[Task stateNamesArray]];
    [state selectItemWithTitle:[task stateAsString]];
    [ok setEnabled:[self canBeModified]];
    [window makeKeyAndOrderFront:self];
  }
  return self;
}

- (void)dealloc 
{ 
  RELEASE(_task);
  RELEASE(_modifiedAlarms);
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
