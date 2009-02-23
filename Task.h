/* emacs buffer mode hint -*- objc -*- */

#import "Date.h"
#import "Element.h"

enum taskState
{
  TK_NONE = 0, 
  TK_INPROCESS, 
  TK_COMPLETED, 
  TK_CANCELED 
};

@interface Task : Element
{
  enum taskState _state;
  Date *_completionDate;
}

+ (NSArray *)stateNamesArray;
- (enum taskState)state;
- (NSString *)stateAsString;
- (void)setState:(enum taskState)state;
- (Date *)completionDate;
- (void)setCompletionDate:(Date *)cd;
@end

@interface Task(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic;
- (BOOL)updateICalComponent:(icalcomponent *)ic;
@end
