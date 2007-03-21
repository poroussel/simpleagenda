/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AgendaStore.h"
#import "StoreManager.h"

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
  NSUserDefaults *_defaults;
  StoreManager *_sm;
}

-(id)initWithStoreManager:(StoreManager *)sm;
-(void)showPreferences;

-(void)editStore:(id)sender;
-(void)deleteStore:(id)sender;
-(void)selectStore:(id)sender;
-(void)changeColor:(id)sender;

@end
