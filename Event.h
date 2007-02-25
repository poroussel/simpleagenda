/* emacs buffer mode hint -*- objc -*- */

#import <ChronographerSource/Date.h>
#import <ChronographerSource/Appointment.h>

@protocol AgendaStore;

@interface Event : Appointment
{
  id <AgendaStore> _store;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle;
- (BOOL)startsBetween:(Date *)start and:(Date *)end;

@end
