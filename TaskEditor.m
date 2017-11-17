/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "TaskEditor.h"
#import "StoreManager.h"
#import "Task.h"
#import "AlarmEditor.h"
#import "HourFormatter.h"
#import "Date.h"

static NSMutableDictionary *editors;

@implementation TaskEditor
- (BOOL)canBeModified
{
  id <MemoryStore> selectedStore = [[StoreManager globalManager] storeForName:[store titleOfSelectedItem]];
  return [selectedStore enabled] && [selectedStore writable];
}

- (id)init
{
  HourFormatter *formatter;
  NSDateFormatter *dateFormatter;

  if (![NSBundle loadNibNamed:@"Task" owner:self])
    return nil;
  if ((self = [super init])) {
    formatter = AUTORELEASE([[HourFormatter alloc] init]);
    dateFormatter = AUTORELEASE([[NSDateFormatter alloc] initWithDateFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortDateFormatString] allowNaturalLanguage:NO]);
    [dueTime setFormatter:formatter];
    [dueDate setFormatter:dateFormatter];
  }
  return self;
}

- (id)document
{
   return nil;
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
    if ([task dueDate]) {
      [dueDate setObjectValue:[[task dueDate] calendarDate]];
      [dueTime setIntValue:[[task dueDate] hourOfDay] * 3600 + [[task dueDate] minuteOfHour] * 60];
      [toggleDueDate setState:YES];
    }
    [dueDate setEnabled:[toggleDueDate state]];
    [dueTime setEnabled:[toggleDueDate state]];
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
  Date *date;

  [_task setSummary:[summary stringValue]];
  [_task setText:[[description textStorage] copy]];
  [_task setState:[state indexOfSelectedItem]];
  [_task setAlarms:_modifiedAlarms];
  if ([toggleDueDate state]) {
    date = [Date dateWithCalendarDate:[dueDate objectValue] withTime:NO];
    date = [Date dateWithTimeInterval:[dueTime intValue] sinceDate:date];
    [_task setDueDate:date];
  } else {
    [_task setDueDate:nil];
  }
  aStore = [sm storeForName:[store titleOfSelectedItem]];
  if (!originalStore)
    [aStore add:_task];
  else if (originalStore == aStore)
    [aStore update:_task];
  else {
    [originalStore remove:_task];
    [aStore add:_task];
  }
  [window close];
  [editors removeObjectForKey:[_task UID]];
}

- (void)cancel:(id)sender
{
  [window close]; 
  [editors removeObjectForKey:[_task UID]]; 
}

- (void)editAlarms:(id)sender
{
  NSArray *alarmArray;

  alarmArray = [AlarmEditor editAlarms:_modifiedAlarms];
  if (alarmArray)
    ASSIGN(_modifiedAlarms, alarmArray);
  [window makeKeyAndOrderFront:self];
}

- (void)toggleDueDate:(id)sender
{
  Date *date;

  [dueDate setEnabled:[toggleDueDate state]];
  [dueTime setEnabled:[toggleDueDate state]];
  if ([toggleDueDate state]) {
    date = [Date now];
    [date changeDayBy:7];
    [dueDate setObjectValue:[date calendarDate]];
    [dueTime setIntValue:[date hourOfDay] * 3600 + [date minuteOfHour] * 60];
  } else {
    [dueDate setObjectValue:nil];
    [dueTime setObjectValue:nil];
  }
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
