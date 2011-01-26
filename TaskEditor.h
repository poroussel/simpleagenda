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
  id toggleDueDate;
  id dueDate;
  id dueTime;
  Task *_task;
  NSArray *_modifiedAlarms;
}

+ (TaskEditor *)editorForTask:(Task *)task;
- (void)validate:(id)sender;
- (void)cancel:(id)sender;
- (void)editAlarms:(id)sender;
- (void)toggleDueDate:(id)sender;
@end
