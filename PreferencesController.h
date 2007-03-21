/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>

@interface PreferencesController : NSObject
{
  IBOutlet id panel;
  IBOutlet id dayStart;
  IBOutlet id dayEnd;
  IBOutlet id minStep;
  IBOutlet id dayStartText;
  IBOutlet id dayEndText;
  IBOutlet id minStepText;
  IBOutlet id storePopUp;
  IBOutlet id storeColor;
  IBOutlet id storeEdit;
  IBOutlet id storeDelete;
  NSUserDefaults *_defaults;
}

-(id)initWithStoreManager:(StoreManager *)sm
-(void)showPreferences;
-(int)integerForKey:(NSString *)key;
-(id)objectForKey:(NSString *)key;

@end
