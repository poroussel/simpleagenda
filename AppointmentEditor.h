/* emacs buffer mode hint -*- objc -*- */

#import "Event.h"
#import "StoreManager.h"

@interface AppointmentEditor : NSObject
{
  id window;
  id description;
  id title;
  id duration;
  id durationText;
  id repeat;
  id endDate;
  id location;
  id store;
  id allDay;
  id ok;
  id until;
  id time;
  id timeText;
  Date *startDate;
  Event *_event;
  NSArray *_modifiedAlarms;
}

+ (AppointmentEditor *)editorForEvent:(Event *)event;
- (void)validate:(id)sender;
- (void)cancel:(id)sender;
- (void)selectFrequency:(id)sender;
- (void)toggleUntil:(id)sender;
- (void)toggleAllDay:(id)sender;
- (void)editAlarms:(id)sender;
@end
