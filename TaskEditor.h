/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@class Task;

@interface TaskEditor : NSObject
{
  id window;
  id description;
  id summary;
  id store;
  id state;
  id ok;
}

- (BOOL)editTask:(Task *)task;
- (void)validate:(id)sender;
- (void)cancel:(id)sender;
@end
