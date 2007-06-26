/* emacs buffer mode hint -*- objc -*- */

#import <ChronographerSource/Date.h>
#import <ChronographerSource/Appointment.h>
#import "AgendaStore.h"

@interface Event : Appointment
{
  id <AgendaStore> _store;
  NSString *_location;
  BOOL _allDay;
  id _externalRef;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle;
- (BOOL)isScheduledBetweenDay:(Date *)start andDay:(Date *)end;
- (id <AgendaStore>)store;
- (void)setStore:(id <AgendaStore>)store;
- (NSString *)location;
- (void)setLocation:(NSString *)aLocation;
- (BOOL)allDay;
- (void)setAllDay:(BOOL)allDay;
- (id)externalRef;
- (void)setExternalRef:(id)externalRef;
- (NSString *)details;

@end
