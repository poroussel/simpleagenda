/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>

@interface PreferencesController : NSObject
{
  IBOutlet id panel;
  IBOutlet id dayStart;
  IBOutlet id dayEnd;
  IBOutlet id dayStartText;
  IBOutlet id dayEndText;
  NSUserDefaults *_defaults;
}

-(id)init;
-(void)showPreferences;
-(int)integerForKey:(NSString *)key;
-(id)objectForKey:(NSString *)key;

@end
