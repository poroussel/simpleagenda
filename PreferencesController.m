/* emacs buffer mode hint -*- objc -*- */

#import "PreferencesController.h"

@implementation PreferencesController


- (void)initDefaults
{
  _defaults = [NSUserDefaults standardUserDefaults];

  if ([_defaults objectForKey:@"firstHour"] == nil)
    [_defaults setInteger:9 forKey:@"firstHour"];

  if ([_defaults objectForKey:@"lastHour"] == nil)
    [_defaults setInteger:18 forKey:@"lastHour"];

  if ([_defaults objectForKey:@"minimumStep"] == nil)
    [_defaults setInteger:15 forKey:@"minimumStep"];

  if ([_defaults objectForKey:@"stores"] == nil) {
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"LocalStore", @"Personal", @"Personal Agenda", nil]
				       forKeys:[NSArray arrayWithObjects:@"storeClass", @"storeFilename", @"storeName", nil]];
    NSArray *array = [NSArray arrayWithObject:dict];
    [_defaults setObject:array forKey:@"stores"];
  }
  if ([_defaults objectForKey:@"defaultStore"] == nil)
    [_defaults setObject:@"Personal Agenda" forKey:@"defaultStore"];
  [_defaults synchronize];
  
}

-(id)init
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Preferences" owner:self])
      return nil;
    [self initDefaults];
  }
  return self;
}

-(void)dealloc
{
  [_defaults release];
  [super dealloc];
}

-(int)integerForKey:(NSString *)key
{
  return [_defaults integerForKey:key];
}

-(id)objectForKey:(NSString *)key
{
  return [_defaults objectForKey:key];
}

-(void)showPreferences
{
  int start = [_defaults integerForKey:@"firstHour"];
  int end = [_defaults integerForKey:@"lastHour"];

  [dayStart setIntValue:start];
  [dayEnd setIntValue:end];
  [dayStartText setIntValue:start];
  [dayEndText setIntValue:end];

  [panel makeKeyAndOrderFront:self];
}

-(void)windowWillClose:(NSNotification *)aNotification
{
  [_defaults setInteger:[dayStart intValue] forKey:@"firstHour"];
  [_defaults setInteger:[dayEnd intValue] forKey:@"lastHour"];
}


@end
