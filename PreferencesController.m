/* emacs buffer mode hint -*- objc -*- */

#import "PreferencesController.h"
#import "HourFormatter.h"
#import "ConfigManager.h"
#import "defines.h"

@implementation PreferencesController

-(id)initWithStoreManager:(StoreManager *)sm
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Preferences" owner:self])
      return nil;

    ASSIGN(_sm, sm);
    HourFormatter *formatter = [[[HourFormatter alloc] init] autorelease];
    [[dayStartText cell] setFormatter:formatter];
    [[dayEndText cell] setFormatter:formatter];
    [[minStepText cell] setFormatter:formatter];
    RETAIN(globalPreferences);
    RETAIN(storePreferences);
    RETAIN(storeFactory);
    [self selectItem:itemPopUp];
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_sm);
  RELEASE(globalPreferences);
  RELEASE(storePreferences);
  RELEASE(storeFactory);
  [super dealloc];
}

-(void)_setupStores
{
  ConfigManager *config = [ConfigManager globalConfig];
  NSString *defaultStore = [config objectForKey:ST_DEFAULT];
  NSEnumerator *list = [_sm storeEnumerator];
  id <AgendaStore> aStore;

  [defaultStorePopUp removeAllItems];
  while ((aStore = [list nextObject])) {
    if ([aStore isWritable])
      [defaultStorePopUp addItemWithTitle:[aStore description]];
  }
  [defaultStorePopUp selectItemWithTitle:defaultStore];

  list = [_sm storeEnumerator];
  [storePopUp removeAllItems];
  while ((aStore = [list nextObject]))
    [storePopUp addItemWithTitle:[aStore description]];
  [storePopUp selectItemAtIndex:0];
  [self selectStore:self];
}

-(void)showPreferences
{
  NSEnumerator *backends = [[_sm registeredBackends] objectEnumerator];
  ConfigManager *config = [ConfigManager globalConfig];
  int start = [config integerForKey:FIRST_HOUR];
  int end = [config integerForKey:LAST_HOUR];
  int step = [config integerForKey:MIN_STEP];
  Class backend;

  [dayStart setIntValue:start];
  [dayEnd setIntValue:end];
  [dayStartText setIntValue:start];
  [dayEndText setIntValue:end];
  [minStep setDoubleValue:step/60.0];
  [minStepText setDoubleValue:step/60.0];

  [self _setupStores];
  [storeClass removeAllItems];
  while ((backend = [backends nextObject]))
    [storeClass addItemWithTitle:[backend storeTypeName]];
  [storeClass selectItemAtIndex:0];
  [createButton setEnabled:NO];
  [panel makeKeyAndOrderFront:self];
}


-(void)selectStore:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [storeColor setColor:[store eventColor]];
  [storeTextColor setColor:[store textColor]];
  [storeDisplay setState:[store displayed]];
  [storeWritable setState:[store isWritable]];
  if ([[defaultStorePopUp titleOfSelectedItem] isEqual:[store description]])
    [removeButton setEnabled:NO];
  else
    [removeButton setEnabled:YES];
}

-(void)changeColor:(id)sender
{
  NSColor *rgb = [[storeColor color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setEventColor:rgb];
}

-(void)changeTextColor:(id)sender
{
  NSColor *rgb = [[storeTextColor color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setTextColor:rgb];
}

-(void)changeStart:(id)sender
{
  int value = [dayStart intValue];
  if (value != [[ConfigManager globalConfig] integerForKey:FIRST_HOUR]) {
    [dayStartText setIntValue:value];
    [[ConfigManager globalConfig] setInteger:value forKey:FIRST_HOUR];
  }
}

-(void)changeEnd:(id)sender
{
  int value = [dayEnd intValue];
  if (value != [[ConfigManager globalConfig] integerForKey:LAST_HOUR]) {
    [dayEndText setIntValue:value];
    [[ConfigManager globalConfig] setInteger:value forKey:LAST_HOUR];
  }
}

-(void)changeStep:(id)sender
{
  double value = [minStep doubleValue];
  if (value * 60 != [[ConfigManager globalConfig] integerForKey:MIN_STEP]) {
    [minStepText setDoubleValue:value];
    [[ConfigManager globalConfig] setInteger:value * 60 forKey:MIN_STEP];
  }
}

-(void)selectDefaultStore:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[defaultStorePopUp titleOfSelectedItem]];
  [[ConfigManager globalConfig] setObject:[store description] forKey:ST_DEFAULT];
}

-(void)toggleDisplay:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setDisplayed:[storeDisplay state]];
}

-(void)toggleWritable:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setIsWritable:[storeWritable state]];
}

/* We only allow the removal of non-default stores */
-(void)removeStore:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  ConfigManager *config = [ConfigManager globalConfig];
  NSMutableArray *storeArray = [config objectForKey:STORES];

  [storeArray removeObject:[store description]];
  [config setObject:storeArray forKey:STORES];
  [config removeObjectForKey:[store description]];
  [_sm removeStoreNamed:[store description]];
  /* FIXME : This could be done by registering STORES key */
  [self _setupStores];
}

-(void)createStore:(id)sender
{
  ConfigManager *config = [ConfigManager globalConfig];
  NSMutableArray *storeArray = [NSMutableArray arrayWithArray:[config objectForKey:STORES]];
  Class backend;

  backend = [_sm backendNamed:[storeClass titleOfSelectedItem]];
  if (backend && [backend registerWithName:[storeName stringValue]]) {
    [_sm addStoreNamed:[storeName stringValue]];
    [storeArray addObject:[storeName stringValue]];
    [config setObject:storeArray forKey:STORES];
    [self _setupStores];
  }
  [storeName setStringValue:@""];
  [createButton setEnabled:NO];
}

-(void)selectItem:(id)sender
{
  switch ([sender indexOfSelectedItem]) {
  case 0:
    [slot setContentView:globalPreferences];
    break;
  case 1:
    [slot setContentView:storePreferences];
    break;
  case 2:
    [slot setContentView:storeFactory];
    break;
  }
}

-(void)controlTextDidChange:(NSNotification *)notification
{
  if ([notification object] == storeName) {
    if ([_sm storeForName:[storeName stringValue]] || ![[storeName stringValue] length])
      [createButton setEnabled:NO];
    else
      [createButton setEnabled:YES];
  }
}

@end
