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
  IBOutlet id storeTextColor;
  IBOutlet id defaultStorePopUp;
  IBOutlet id storeDisplay;
  IBOutlet id storeWritable;
  IBOutlet id storeRefresh;
  IBOutlet id storeEnabled;
  IBOutlet id refreshInterval;
  IBOutlet id refreshIntervalText;
  IBOutlet id removeButton;
  IBOutlet id storeClass;
  IBOutlet id storeName;
  IBOutlet id createButton;
  IBOutlet NSBox *slot;
  IBOutlet id globalPreferences;
  IBOutlet id storePreferences;
  IBOutlet id storeFactory;
  IBOutlet id itemPopUp;
  IBOutlet id showTooltip;
  IBOutlet id uiPreferences;
  IBOutlet id showDateAppIcon;
  IBOutlet id showTimeAppIcon;
  IBOutlet id alarmPreferences;
  IBOutlet id alarmEnabled;
  IBOutlet id alarmBackendPopUp;
  StoreManager *_sm;
}

- (void)showPreferences;
- (void)selectStore:(id)sender;
- (void)changeColor:(id)sender;
- (void)changeTextColor:(id)sender;
- (void)changeStart:(id)sender;
- (void)changeEnd:(id)sender;
- (void)changeStep:(id)sender;
- (void)changeInterval:(id)sender;
- (void)selectDefaultStore:(id)sender;
- (void)toggleDisplay:(id)sender;
- (void)toggleWritable:(id)sender;
- (void)toggleRefresh:(id)sender;
- (void)toggleEnabled:(id)sender;
- (void)removeStore:(id)sender;
- (void)createStore:(id)sender;
- (void)selectItem:(id)sender;
- (void)toggleTooltip:(id)sender;
- (void)toggleShowDate:(id)sender;
- (void)toggleShowTime:(id)sender;
- (void)toggleAlarms:(id)sender;
- (void)selectAlarmBackend:(id)sender;
@end
