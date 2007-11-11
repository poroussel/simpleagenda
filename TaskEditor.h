/* emacs buffer mode hint -*- objc -*- */

#import "Task.h"
#import "StoreManager.h"

@interface TaskEditor : NSObject
{
  id window;
  id description;
  id summary;
  id store;
  id state;
  id ok;
}

- (BOOL)editTask:(Task *)data withStoreManager:(StoreManager *)sm;
- (void)validate:(id)sender;
- (void)cancel:(id)sender;

@end
