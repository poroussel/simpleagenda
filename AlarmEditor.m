#import <AppKit/AppKit.h>
#import "AlarmEditor.h"
#import "Element.h"
#import "Alarm.h"
#import "HourFormatter.h"

@implementation AlarmEditor
- (void)setupForAlarm:(Alarm *)alarm
{
  NSTimeInterval relativeTrigger;

  _current = alarm;
  if ([alarm isAbsoluteTrigger]) {
    [type selectItemAtIndex:1];
  } else {
    [type selectItemAtIndex:0];
    relativeTrigger = [alarm relativeTrigger];
    if (relativeTrigger >= 0) {
      [radio selectCellWithTag:1];
      [relativeSlider setFloatValue:relativeTrigger/3600];
    } else {
      [radio selectCellWithTag:0];
      [relativeSlider setFloatValue:-relativeTrigger/3600];
    }
    [self changeDelay:self];
    [self selectType:self];
  }
}

- (id)init
{
  HourFormatter *formatter;

  if (![NSBundle loadNibNamed:@"Alarm" owner:self]) {
    DESTROY(self);
  }
  if ((self = [super init])) {
    _current = nil;
    _simple = RETAIN([Alarm alarm]);
    [_simple setRelativeTrigger:-15*60];
    [_simple setAction:ICAL_ACTION_DISPLAY];
    
    [table setDelegate:self];

    [type removeAllItems];
    [type addItemsWithTitles:[NSArray arrayWithObjects:_(@"Relative"), _(@"Absolute"), nil]];
    [action removeAllItems];
    [action addItemsWithTitles:[NSArray arrayWithObjects:_(@"Display"), _(@"Sound"), _(@"Email"), _(@"Procedure"), nil]];

    [table setUsesAlternatingRowBackgroundColors:YES];
    [table sizeLastColumnToFit];

    formatter = [[[HourFormatter alloc] init] autorelease];
    [[relativeText cell] setFormatter:formatter];

  }
  return self;
}

- (id)initWithAlarms:(NSArray *)alarms
{
  if ((self = [self init])) {
    _alarms = [[NSMutableArray alloc] initWithArray:alarms copyItems:YES];
    if ([_alarms count] == 0) {
      [self setupForAlarm:_simple];
      [remove setEnabled:NO];
    } else {
      [remove setEnabled:YES];
    }
    [table reloadData];
  }
  return self;
}

- (NSArray *)run
{
  [NSApp runModalForWindow:window];
  return [NSArray arrayWithArray:_alarms];
}

+ (NSArray *)editAlarms:(NSArray *)alarms
{
  AlarmEditor *editor;
  NSArray *modified;

  if ((editor = [[AlarmEditor alloc] initWithAlarms:alarms])) {
    modified = [editor run];
    [editor release];
    return modified;
  }
  return nil;
}

- (void)dealloc
{
  DESTROY(_simple);
  DESTROY(_alarms);
  [super dealloc];
}

- (void)addAlarm:(id)sender
{
  [_alarms addObject:AUTORELEASE([_simple copy])];
  [table reloadData];
  [table selectRow:[_alarms count]-1 byExtendingSelection:NO];
  [remove setEnabled:YES];
}

- (void)removeAlarm:(id)sender
{
  [_alarms removeObjectAtIndex:[table selectedRow]];
  [table reloadData];
  if ([_alarms count] > 0)
    [self tableViewSelectionDidChange:nil];
  else
    [remove setEnabled:NO];
}

- (void)selectType:(id)sender
{
  if ([type indexOfSelectedItem] == 0) {
    [relativeSlider setEnabled:YES];
    [radio setEnabled:YES];
  } else {
    [relativeSlider setEnabled:NO];
    [radio setEnabled:NO];
  }
}

- (void)changeDelay:(id)sender
{
  [relativeText setFloatValue:[relativeSlider floatValue]];
  if (_current) {
    if ([[radio selectedCell] tag] == 0)
      [_current setRelativeTrigger:[relativeSlider floatValue] * -3600];
    else
      [_current setRelativeTrigger:[relativeSlider floatValue] * 3600];
    [table reloadData];
  }
}

- (void)switchBeforeAfter:(id)sender
{
  [self changeDelay:self];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  if ([_alarms count] > 0)
    [self setupForAlarm:[_alarms objectAtIndex:[table selectedRow]]];
}
@end

@implementation AlarmEditor(NSTableViewDataSource)
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [_alarms count];
}
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  return NO;
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  return [[_alarms objectAtIndex:rowIndex] shortDescription];
}
@end
