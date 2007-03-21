/* emacs buffer mode hint -*- objc -*- */

#import "PreferencesController.h"
#import "HourFormatter.h"

@implementation PreferencesController


-(id)init
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Preferences" owner:self])
      return nil;

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
  [_defaults release];
  [super dealloc];
}

-(void)showPreferences
{
  int start = [_defaults integerForKey:@"firstHour"];
  int end = [_defaults integerForKey:@"lastHour"];
  int step = [_defaults integerForKey:@"minimumStep"];

  [dayStart setIntValue:start];
  [dayEnd setIntValue:end];
  [dayStartText setIntValue:start];
  [dayEndText setIntValue:end];
  [minStep setDoubleValue:step/60.0];
  [minStepText setDoubleValue:step/60.0];

  [panel makeKeyAndOrderFront:self];
}

-(void)windowWillClose:(NSNotification *)aNotification
{
  [_defaults setInteger:[dayStart intValue] forKey:@"firstHour"];
  [_defaults setInteger:[dayEnd intValue] forKey:@"lastHour"];
  [_defaults setInteger:[minStep doubleValue] * 60 forKey:@"minimumStep"];
  [_defaults synchronize];
}


@end
