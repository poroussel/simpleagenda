/* emacs buffer mode hint -*- objc -*- */

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
}

- (BOOL)editAppointment:(Appointment *)data;
- (void)validate:(id)sender;
- (void)cancel:(id)sender;

@end
