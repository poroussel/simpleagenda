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
  IBOutlet id defaultStorePopUp;
  IBOutlet id storeDisplay;
  IBOutlet id storeWritable;
  IBOutlet id removeButton;
  IBOutlet id storeClass;
  StoreManager *_sm;
}

-(id)initWithStoreManager:(StoreManager *)sm;
-(void)showPreferences;

-(void)selectStore:(id)sender;
-(void)changeColor:(id)sender;
-(void)changeStart:(id)sender;
-(void)changeEnd:(id)sender;
-(void)changeStep:(id)sender;
-(void)selectDefaultStore:(id)sender;
-(void)toggleDisplay:(id)sender;
-(void)toggleWritable:(id)sender;
-(void)removeStore:(id)sender;
-(void)createStore:(id)sender;

@end
