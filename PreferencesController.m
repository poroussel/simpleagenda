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
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_sm);
  [super dealloc];
}

-(void)_setupStoresPopup
{
  NSEnumerator *list = [_sm storeEnumerator];
  id <AgendaStore> aStore;

  [storePopUp removeAllItems];
  while ((aStore = [list nextObject]))
    [storePopUp addItemWithTitle:[aStore description]];
  [storePopUp selectItemAtIndex:0];
  [self selectStore:self];
}

-(void)showPreferences
{
  NSEnumerator *list = [_sm storeEnumerator];
  ConfigManager *config = [ConfigManager globalConfig];
  NSString *defaultStore = [config objectForKey:ST_DEFAULT];
  int start = [config integerForKey:FIRST_HOUR];
  int end = [config integerForKey:LAST_HOUR];
  int step = [config integerForKey:MIN_STEP];
  id <AgendaStore> aStore;

  [dayStart setIntValue:start];
  [dayEnd setIntValue:end];
  [dayStartText setIntValue:start];
  [dayEndText setIntValue:end];
  [minStep setDoubleValue:step/60.0];
  [minStepText setDoubleValue:step/60.0];

  [defaultStorePopUp removeAllItems];
  while ((aStore = [list nextObject])) {
    if ([aStore isWritable])
      [defaultStorePopUp addItemWithTitle:[aStore description]];
  }
  [defaultStorePopUp selectItemWithTitle:defaultStore];
  [self _setupStoresPopup];
  [panel makeKeyAndOrderFront:self];
}


-(void)selectStore:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [storeColor setColor:[store eventColor]];
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

  [_sm removeStoreNamed:[store description]];
  [storeArray removeObject:[store description]];
  [config setObject:storeArray forKey:STORES];
  [config removeObjectForKey:[store description]];
  /* FIXME : This could be done by registering STORES key */
  [self _setupStoresPopup];
}

@end
