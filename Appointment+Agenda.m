/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import <ChronographerSource/Date.h>
#import <ChronographerSource/Appointment.h>
#import "Appointment+Agenda.h"

@implementation Appointment(Agenda)

- (BOOL)startsBetween:(Date *)start and:(Date *)end
{
  /* FIXME : do something for recurrent appointments */
  if ([startDate isEqual:start] == YES)
    return YES;
  if ([startDate compare:start] == NSOrderedDescending && [startDate compare:end] == NSOrderedAscending) {
    return YES;
  }
  return NO;
}

@end
