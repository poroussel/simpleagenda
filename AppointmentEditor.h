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
  id endDateStepper;
  id location;
  id store;
}

- (BOOL)editAppointment:(Event *)data withStoreManager:(StoreManager *)sm;
- (void)validate:(id)sender;
- (void)cancel:(id)sender;

@end
