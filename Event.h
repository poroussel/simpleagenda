/* emacs buffer mode hint -*- objc -*- */

#import <ChronographerSource/Date.h>
#import <ChronographerSource/Appointment.h>

@protocol AgendaStore;

@interface Event : Appointment
{
  id <AgendaStore> _store;
  NSString *location;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle;
- (BOOL)startsBetween:(Date *)start and:(Date *)end;
- (id <AgendaStore>)store;
- (void)setStore:(id <AgendaStore>)store;
- (NSString *)location;
- (void)setLocation:(NSString *)aLocation;

@end
