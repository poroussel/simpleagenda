#import <AppKit/AppKit.h>
#import "AlarmEditor.h"
#import "Element.h"

@implementation AlarmEditor
- (id)init
{
  if (![NSBundle loadNibNamed:@"Alarm" owner:self]) {
    DESTROY(self);
  }
  if ((self = [super init])) {
    [type removeAllItems];
    [type addItemsWithTitles:[NSArray arrayWithObjects:_(@"Relative"), _(@"Absolute"), nil]];
    [action removeAllItems];
    [action addItemsWithTitles:[NSArray arrayWithObjects:_(@"Display"), _(@"Sound"), _(@"Email"), _(@"Procedure"), nil]];

    [table setUsesAlternatingRowBackgroundColors:YES];
    [table sizeLastColumnToFit];
  }
  return self;
}

- (id)initWithAlarms:(NSArray *)alarms
{
  if ((self = [self init])) {
    _alarms = [alarms mutableCopy];
    [table reloadData];
  }
  return self;
}

- (int)run
{
  return [NSApp runModalForWindow:window];
}

+ (NSArray *)editAlarms:(NSArray *)alarms
{
  AlarmEditor *editor;

  if ((editor = [[AlarmEditor alloc] initWithAlarms:alarms])) {
    [editor run];
    [editor release];
  }
  return alarms;
}

- (void)dealloc
{
  NSLog(@"Dealloc AlarmEditor");
  [_alarms release];
  [super dealloc];
}
@end

@implementation AlarmEditor(NSTableViewDataSource)
- (int) numberOfRowsInTableView: (NSTableView*)aTableView
{
  return [_alarms count];
}

- (BOOL) tableView: (NSTableView*)tableView acceptDrop: (id)info row: (int)row dropOperation: (NSTableViewDropOperation)operation
{
  return NO;
}

- (id) tableView: (NSTableView*)aTableView objectValueForTableColumn: (NSTableColumn*)aTableColumn row: (int)rowIndex
{
  return [[_alarms objectAtIndex:rowIndex] description];
}

- (void) tableView: (NSTableView*)aTableView setObjectValue: (id)anObject forTableColumn: (NSTableColumn*)aTableColumn row: (int)rowIndex
{
}

- (NSDragOperation) tableView: (NSTableView*)tableView validateDrop: (id)info proposedRow: (int)row proposedDropOperation: (NSTableViewDropOperation)operation
{
  return 0;
}

- (BOOL) tableView: (NSTableView*)tableView writeRows: (NSArray*)rows toPasteboard: (NSPasteboard*)pboard
{
  return NO;
}

- (BOOL) tableView: (NSTableView*)tableView writeRowsWithIndexes: (NSIndexSet*)rows toPasteboard: (NSPasteboard*)pboard
{
  return NO;
}
@end
