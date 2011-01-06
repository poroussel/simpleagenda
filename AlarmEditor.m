#import <AppKit/AppKit.h>
#import "AlarmEditor.h"
#import "Element.h"
#import "SAAlarm.h"

@implementation AlarmEditor
- (id)init
{
  if (![NSBundle loadNibNamed:@"Alarm" owner:self]) {
    DESTROY(self);
  }
  if ((self = [super init])) {
    [table setDelegate:self];

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
  [_alarms release];
  [super dealloc];
}

- (void)addAlarm:(id)sender
{
  SAAlarm *alarm = [SAAlarm alarm];

  [alarm setRelativeTrigger:-15*60];
  [alarm setAction:ICAL_ACTION_DISPLAY];
  [_alarms addObject:alarm];
  [table reloadData];
}

- (void)removeAlarm:(id)sender
{
  NSLog(@"removeAlarm");
}

- (void)selectType:(id)sender
{
  NSLog(@"selectType");
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  //int index = [table selectedRow];
  NSLog(@"selection changed");
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
  return [[_alarms objectAtIndex:rowIndex] shortDescription];
}
@end
