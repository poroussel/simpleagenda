/* emacs buffer mode hint -*- objc -*- */

#import "PreferencesController.h"
#import "HourFormatter.h"

@implementation PreferencesController

-(id)initWithStoreManager:(StoreManager *)sm
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Preferences" owner:self])
      return nil;

    _sm = RETAIN(sm);
    _defaults = [NSUserDefaults standardUserDefaults];
    HourFormatter *formatter = [[[HourFormatter alloc] init] autorelease];
    [[dayStartText cell] setFormatter:formatter];
    [[dayEndText cell] setFormatter:formatter];
    [[minStepText cell] setFormatter:formatter];
  }
  return self;
}

-(void)dealloc
{
  RELEASE(_sm);
  [_defaults release];
  [super dealloc];
}

-(void)showPreferences
{
  NSEnumerator *list = [_sm objectEnumerator];
  id <AgendaStore> aStore;
  int start = [_defaults integerForKey:@"firstHour"];
  int end = [_defaults integerForKey:@"lastHour"];
  int step = [_defaults integerForKey:@"minimumStep"];

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

  [panel makeKeyAndOrderFront:self];
}

-(void)windowWillClose:(NSNotification *)aNotification
{
  [_defaults setInteger:[dayStart intValue] forKey:@"firstHour"];
  [_defaults setInteger:[dayEnd intValue] forKey:@"lastHour"];
  [_defaults setInteger:[minStep doubleValue] * 60 forKey:@"minimumStep"];
  [_defaults synchronize];
}


-(void)editStore:(id)sender
{
}

-(void)deleteStore:(id)sender
{
}

-(void)selectStore:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [storeColor setColor:[store eventColor]];
}

-(void)changeColor:(id)sender
{
  id <AgendaStore> store = [_sm storeForName:[storePopUp titleOfSelectedItem]];
  [store setEventColor:[storeColor color]];
  [_defaults synchronize];
}

@end
