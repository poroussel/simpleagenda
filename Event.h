/* emacs buffer mode hint -*- objc -*- */

#import <ChronographerSource/Date.h>
#import <ChronographerSource/Appointment.h>

@protocol AgendaStore;

@interface Event : Appointment
{
  id <AgendaStore> _store;
  NSString *_location;
  BOOL _allDay;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle;
- (BOOL)isScheduledForDay:(Date *)day;
- (id <AgendaStore>)store;
- (void)setStore:(id <AgendaStore>)store;
- (NSString *)location;
- (void)setLocation:(NSString *)aLocation;
- (BOOL)allDay;
- (void)setAllDay:(BOOL)allDay;

@end
