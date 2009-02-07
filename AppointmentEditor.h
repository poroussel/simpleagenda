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
  Date *startDate;
}

- (BOOL)editAppointment:(Event *)event;
- (void)validate:(id)sender;
- (void)cancel:(id)sender;
- (void)selectFrequency:(id)sender;
- (void)toggleUntil:(id)sender;
- (void)toggleAllDay:(id)sender;
@end
