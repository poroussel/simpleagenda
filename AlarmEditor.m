#import <AppKit/AppKit.h>
#import "AlarmEditor.h"
#import "Element.h"
#import "Alarm.h"
#import "HourFormatter.h"

@implementation AlarmEditor
- (void)setupForSelection
{
  NSTimeInterval relativeTrigger;
  Date *d;

  if ([_alarms count] == 0) {
    [action setEnabled:NO];
    [type setEnabled:NO];
    [relativeSlider setEnabled:NO];
    [radio setEnabled:NO];
    [date setEnabled:NO];
    [time setEnabled:NO];
    [date setObjectValue:nil];
    [date setObjectValue:nil];
    [remove setEnabled:NO];
    _current = nil;
    return;
  }
  [action setEnabled:YES];
  [type setEnabled:YES];
  [remove setEnabled:YES];
  _current = [_alarms objectAtIndex:[table selectedRow]];
  if ([_current isAbsoluteTrigger]) {
    [relativeSlider setEnabled:NO];
    [radio setEnabled:NO];
    [date setEnabled:YES];
    [time setEnabled:YES];
    d = [_current absoluteTrigger];
    [date setObjectValue:[d calendarDate]];
    [time setIntValue:[d hourOfDay] * 3600 + [d minuteOfHour] * 60];
    [type selectItemAtIndex:1];
  } else {
    [relativeSlider setEnabled:YES];
    [radio setEnabled:YES];
    [date setEnabled:NO];
    [time setEnabled:NO];
    [date setObjectValue:nil];
    [date setObjectValue:nil];
    [type selectItemAtIndex:0];
    relativeTrigger = [_current relativeTrigger];
    if (relativeTrigger >= 0) {
      [radio selectCellWithTag:1];
      [relativeSlider setFloatValue:relativeTrigger];
    } else {
      [radio selectCellWithTag:0];
      [relativeSlider setFloatValue:-relativeTrigger];
    }
    [relativeText setFloatValue:[relativeSlider floatValue]];
  }
}

- (id)init
{
  HourFormatter *formatter;
  NSDateFormatter *dateFormatter;

  if (![NSBundle loadNibNamed:@"Alarm" owner:self])
    return nil;
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

    formatter = AUTORELEASE([[HourFormatter alloc] init]);
    dateFormatter = AUTORELEASE([[NSDateFormatter alloc] initWithDateFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortDateFormatString] allowNaturalLanguage:NO]);
    [[relativeText cell] setFormatter:formatter];
    [time setFormatter:formatter];
    [date setFormatter:dateFormatter];
  }
  return self;
}

- (id)initWithAlarms:(NSArray *)alarms
{
  if ((self = [self init])) {
    _alarms = [[NSMutableArray alloc] initWithArray:alarms copyItems:YES];
    [table reloadData];
    [self setupForSelection];
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
}

- (void)removeAlarm:(id)sender
{
  [_alarms removeObjectAtIndex:[table selectedRow]];
  [table reloadData];
  [self tableViewSelectionDidChange:nil];
}

- (void)selectType:(id)sender
{
  Date *d;

  if ([type indexOfSelectedItem] == 1) {
    d = [Date now];
    [d changeDayBy:7];
    [date setObjectValue:[d calendarDate]];
    [time setFloatValue:([d hourOfDay]*60 + [d minuteOfHour]) / 60.0];
    [_current setAbsoluteTrigger:d];
    [table reloadData];
  } else {
    [self changeDelay:nil];
  }
  [self setupForSelection];
}

- (void)changeDelay:(id)sender
{
  [relativeText setIntValue:[relativeSlider intValue]];
  if ([[radio selectedCell] tag] == 0)
    [_current setRelativeTrigger:-[relativeSlider intValue]];
  else
    [_current setRelativeTrigger:[relativeSlider intValue]];
  [table reloadData];
}

- (void)switchBeforeAfter:(id)sender
{
  [self changeDelay:self];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  [self setupForSelection];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  Date *d;

  if (_current && [date objectValue] && [time objectValue]) {
    d = [Date dateWithCalendarDate:[date objectValue] withTime:NO];
    d = [Date dateWithTimeInterval:[time intValue] sinceDate:d];
    [_current setAbsoluteTrigger:d];
    [table reloadData];
  }
}
@end

@implementation AlarmEditor(NSTableViewDataSource)
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [_alarms count];
}
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  return NO;
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
  return [[_alarms objectAtIndex:rowIndex] shortDescription];
}
@end
