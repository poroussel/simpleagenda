/* emacs buffer mode hint -*- objc -*- */

@interface Appointment(Agenda)

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)title;
- (BOOL)startsBetween:(Date *)start and:(Date *)end;

@end
