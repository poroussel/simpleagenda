/* emacs buffer mode hint -*- objc -*- */

#import "PreferencesController.h"
#import "HourFormatter.h"
#import "defines.h"

@implementation PreferencesController

-(id)initWithStoreManager:(StoreManager *)sm
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Preferences" owner:self])
      return nil;

    ASSIGN(_sm, sm);
    _defaults = [UserDefaults sharedInstance];
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

-(void)showPreferences
{
  NSEnumerator *list = [_sm objectEnumerator];
  id <AgendaStore> aStore;
  int start = [_defaults integerForKey:FIRST_HOUR];
  int end = [_defaults integerForKey:LAST_HOUR];
  int step = [_defaults integerForKey:MIN_STEP];
  NSString *defaultStore = [_defaults objectForKey:ST_DEFAULT];

  [dayStart setIntValue:start];
  [dayEnd setIntValue:end];
  [dayStartText setIntValue:start];
  [dayEndText setIntValue:end];
  [minStep setDoubleValue:step/60.0];
  [minStepText setDoubleValue:step/60.0];

  /* This could be done during init ? */
  [storePopUp removeAllItems];
  while ((aStore = [list nextObject]))
    [storePopUp addItemWithTitle:[aStore description]];
  [storePopUp selectItemAtIndex:0];
  [self selectStore:self];

  list = [_sm objectEnumerator];
  [defaultStorePopUp removeAllItems];
  while ((aStore = [list nextObject])) {
    if ([aStore isWritable])
      [defaultStorePopUp addItemWithTitle:[aStore description]];
  }
  [defaultStorePopUp selectItemWithTitle:defaultStore];

  [panel makeKeyAndOrderFront:self];
}


-(void)selectStore:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [storeColor setColor:[store eventColor]];
  [storeDisplay setState:[store displayed]];
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
  if (value != [_defaults integerForKey:FIRST_HOUR]) {
    [dayStartText setIntValue:value];
    [_defaults setInteger:value forKey:FIRST_HOUR];
  }
}

-(void)changeEnd:(id)sender
{
  int value = [dayEnd intValue];
  if (value != [_defaults integerForKey:LAST_HOUR]) {
    [dayEndText setIntValue:value];
    [_defaults setInteger:value forKey:LAST_HOUR];
  }
}

-(void)changeStep:(id)sender
{
  double value = [minStep doubleValue];
  if (value * 60 != [_defaults integerForKey:MIN_STEP]) {
    [minStepText setDoubleValue:value];
    [_defaults setInteger:value * 60 forKey:MIN_STEP];
  }
}

-(void)selectDefaultStore:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[defaultStorePopUp titleOfSelectedItem]];
  [_defaults setObject:[store description] forKey:ST_DEFAULT];
}

-(void)toggleDisplay:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setDisplayed:[storeDisplay state]];
}

@end
