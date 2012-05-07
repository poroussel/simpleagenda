/* emacs buffer mode hint -*- objc -*- */

#import "PreferencesController.h"
#import "HourFormatter.h"
#import "ConfigManager.h"
#import "AlarmManager.h"
#import "AlarmBackend.h"
#import "defines.h"

@implementation PreferencesController
- (id)init
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Preferences" owner:self])
      return nil;

    _sm = [StoreManager globalManager];
    HourFormatter *formatter = [[[HourFormatter alloc] init] autorelease];
    [[dayStartText cell] setFormatter:formatter];
    [[dayEndText cell] setFormatter:formatter];
    [[minStepText cell] setFormatter:formatter];
    [[refreshIntervalText cell] setFormatter:formatter];
    RETAIN(globalPreferences);
    RETAIN(storePreferences);
    RETAIN(storeFactory);
    RETAIN(uiPreferences);
    RETAIN(alarmPreferences);
    [self selectItem:itemPopUp];
    [panel setFrameAutosaveName:@"preferencesPanel"];
    /* FIXME : could we call setupDefaultStore directly ? */
    [[NSNotificationCenter defaultCenter] addObserver:self 
					  selector:@selector(storeStateChanged:) 
					  name:SAStatusChangedForStore 
					  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self 
 					  selector:@selector(storeStateChanged:) 
 					  name:SAEnabledStatusChangedForStore 
					  object:nil];
  }
  return self;
}

- (void)dealloc
{
  RELEASE(globalPreferences);
  RELEASE(storePreferences);
  RELEASE(storeFactory);
  RELEASE(uiPreferences);
  RELEASE(alarmPreferences);
  [super dealloc];
}

- (void)setupDefaultStore
{
  NSString *defaultStore = [[ConfigManager globalConfig] objectForKey:ST_DEFAULT];
  NSEnumerator *list = [_sm storeEnumerator];
  id <AgendaStore> aStore;

  [defaultStorePopUp removeAllItems];
  while ((aStore = [list nextObject])) {
    if ([aStore writable] && [aStore enabled])
      [defaultStorePopUp addItemWithTitle:[aStore description]];
  }
  if ([defaultStorePopUp numberOfItems] > 0) {
    if ([defaultStorePopUp itemWithTitle:defaultStore])
      [defaultStorePopUp selectItemWithTitle:defaultStore];
    else {
      [defaultStorePopUp selectItemAtIndex:0];
      [self selectDefaultStore:self];
    }
  }
}

- (void)setupStores
{
  NSEnumerator *list;
  id <AgendaStore> aStore;

  [self setupDefaultStore];
  list = [_sm storeEnumerator];
  [storePopUp removeAllItems];
  while ((aStore = [list nextObject]))
    [storePopUp addItemWithTitle:[aStore description]];
  [storePopUp selectItemAtIndex:0];
  [self selectStore:self];
}

- (void)storeStateChanged:(NSNotification *)notification
{
  [self setupDefaultStore];
  [self selectStore:nil];
}

- (void)showPreferences
{
  ConfigManager *config = [ConfigManager globalConfig];
  NSEnumerator *backends;
  int start = [config integerForKey:FIRST_HOUR];
  int end = [config integerForKey:LAST_HOUR];
  int step = [config integerForKey:MIN_STEP];
  Class backend;
  NSString *name;

  [dayStart setIntValue:start*3600];
  [dayEnd setIntValue:end*3600];
  [dayStartText setIntValue:start*3600];
  [dayEndText setIntValue:end*3600];
  [minStep setIntValue:step * 60];
  [minStepText setIntValue:step * 60];
  [showTooltip setState:[config integerForKey:TOOLTIP]];
  [showDateAppIcon setState:[config integerForKey:APPICON_DATE]];
  [showTimeAppIcon setState:[config integerForKey:APPICON_TIME]];

  [alarmEnabled setState:[[AlarmManager globalManager] alarmsEnabled]];
  [alarmBackendPopUp removeAllItems];
  backends = [[AlarmManager backends] objectEnumerator];
  while ((backend = [backends nextObject]))
    [alarmBackendPopUp addItemWithTitle:[[backend class] backendName]];

  name = [[AlarmManager globalManager] defaultBackendName];
  if ([alarmBackendPopUp itemWithTitle:name])
    [alarmBackendPopUp selectItemWithTitle:name];

  [self setupStores];
  [storeClass removeAllItems];
  backends = [[StoreManager backends] objectEnumerator];
  while ((backend = [backends nextObject]))
    if ([backend isUserInstanciable])
      [storeClass addItemWithTitle:[backend storeTypeName]];
  [storeClass selectItemAtIndex:0];
  [createButton setEnabled:NO];
  [panel makeKeyAndOrderFront:self];
}


- (void)periodicSetupForStore:(id)store
{
  if ([store conformsToProtocol:@protocol(PeriodicRefresh)]) {
    [storeRefresh setEnabled:YES];
    [storeRefresh setState:[store periodicRefresh]];
    [refreshInterval setEnabled:[store periodicRefresh]];
    [refreshIntervalText setEnabled:[store periodicRefresh]];
    [refreshIntervalText setIntValue:[store refreshInterval]];
    [refreshInterval setIntValue:[store refreshInterval]];
  } else {
    [storeRefresh setEnabled:NO];
    [storeRefresh setState:NO];
    [refreshInterval setEnabled:NO];
    [refreshIntervalText setEnabled:NO];
    [refreshIntervalText setIntValue:0];
    [refreshInterval setIntValue:0];
  }
}

- (void)selectStore:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [storeColor setColor:[store eventColor]];
  [storeTextColor setColor:[store textColor]];
  [storeDisplay setState:[store displayed]];
  [storeWritable setState:[store writable]];
  [storeEnabled setState:[store enabled]];
  if ([[defaultStorePopUp titleOfSelectedItem] isEqual:[store description]])
    [removeButton setEnabled:NO];
  else
    [removeButton setEnabled:YES];
  [self periodicSetupForStore:store];
}

- (void)changeColor:(id)sender
{
  NSColor *rgb = [[storeColor color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setEventColor:rgb];
}

- (void)changeTextColor:(id)sender
{
  NSColor *rgb = [[storeTextColor color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setTextColor:rgb];
}

- (void)changeStart:(id)sender
{
  int value = [dayStart intValue] / 3600;
  if (value != [[ConfigManager globalConfig] integerForKey:FIRST_HOUR]) {
    [dayStartText setIntValue:value * 3600];
    [[ConfigManager globalConfig] setInteger:value forKey:FIRST_HOUR];
  }
}

- (void)changeEnd:(id)sender
{
  int value = [dayEnd intValue] / 3600;
  if (value != [[ConfigManager globalConfig] integerForKey:LAST_HOUR]) {
    [dayEndText setIntValue:value * 3600];
    [[ConfigManager globalConfig] setInteger:value forKey:LAST_HOUR];
  }
}

- (void)changeStep:(id)sender
{
  int value = [minStep intValue] / 60;
  if (value != [[ConfigManager globalConfig] integerForKey:MIN_STEP]) {
    [minStepText setIntValue:value * 60];
    [[ConfigManager globalConfig] setInteger:value forKey:MIN_STEP];
  }
}

- (void)changeInterval:(id)sender
{
  int value = [refreshInterval intValue];
  id <PeriodicRefresh> store = (id <PeriodicRefresh>)[_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setRefreshInterval:value];
  [refreshIntervalText setIntValue:value];
  [refreshInterval setIntValue:value];
}

- (void)selectDefaultStore:(id)sender
{
  [_sm setDefaultStore:[defaultStorePopUp titleOfSelectedItem]];
  [self selectStore:nil];
}

- (void)toggleDisplay:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setDisplayed:[storeDisplay state]];
}

- (void)toggleWritable:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setWritable:[storeWritable state]];
}

- (void)toggleRefresh:(id)sender
{
  id <PeriodicRefresh> store = (id <PeriodicRefresh>)[_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setPeriodicRefresh:[storeRefresh state]];
  [self periodicSetupForStore:store];
}

- (void)toggleEnabled:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setEnabled:[storeEnabled state]];
}

- (void)toggleTooltip:(id)sender
{
  [[ConfigManager globalConfig] setInteger:[showTooltip state] forKey:TOOLTIP];
}

- (void)toggleShowDate:(id)sender
{
  [[ConfigManager globalConfig] setInteger:[showDateAppIcon state] forKey:APPICON_DATE];
}

- (void)toggleShowTime:(id)sender
{
  [[ConfigManager globalConfig] setInteger:[showTimeAppIcon state] forKey:APPICON_TIME];
}

- (void)toggleAlarms:(id)sender
{
  [[AlarmManager globalManager] setAlarmsEnabled:[alarmEnabled state]];
}

- (void)selectAlarmBackend:(id)sender
{
  [[AlarmManager globalManager] setDefaultBackend:[alarmBackendPopUp titleOfSelectedItem]];
}

/* We only allow the removal of non-default stores */
- (void)removeStore:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  ConfigManager *config = [ConfigManager globalConfig];
  NSMutableArray *storeArray = [NSMutableArray arrayWithArray:[config objectForKey:STORES]];

  [storeArray removeObject:[store description]];
  [config setObject:storeArray forKey:STORES];
  [config removeObjectForKey:[store description]];
  [_sm removeStoreNamed:[store description]];
  /* FIXME : This could be done by registering STORES key */
  [self setupStores];
}

- (void)createStore:(id)sender
{
  ConfigManager *config = [ConfigManager globalConfig];
  NSMutableArray *storeArray = [NSMutableArray arrayWithArray:[config objectForKey:STORES]];
  Class backend;

  backend = [StoreManager backendForName:[storeClass titleOfSelectedItem]];
  if (backend && [backend registerWithName:[storeName stringValue]]) {
    [_sm addStoreNamed:[storeName stringValue]];
    [storeArray addObject:[storeName stringValue]];
    [config setObject:storeArray forKey:STORES];
    [self setupStores];
  }
  [storeName setStringValue:@""];
  [createButton setEnabled:NO];
}

- (void)setContent:(id)content
{
  id old = [slot contentView];

  if (old == content)
    return;
  [slot setContentView: content];
  [itemPopUp setNextKeyView:[slot contentView]];
}


- (void)selectItem:(id)sender
{
  switch ([sender indexOfSelectedItem]) {
  case 0:
    [self setContent:globalPreferences];
    break;
  case 1:
    [self setContent:storePreferences];
    break;
  case 2:
    [self setContent:storeFactory];
    break;
  case 3:
    [self setContent:uiPreferences];
    break;
  case 4:
    [self setContent:alarmPreferences];
    break;
  }
}

- (void)controlTextDidChange:(NSNotification *)notification
{
  if ([notification object] == storeName) {
    if ([_sm storeForName:[storeName stringValue]] || ![[storeName stringValue] length])
      [createButton setEnabled:NO];
    else
      [createButton setEnabled:YES];
  }
}
@end
