/* emacs buffer mode hint -*- objc -*- */

#import "Date.h"
#import "Element.h"
#import "RecurrenceRule.h"

@interface Event : Element
{
  NSString *_location;
  BOOL _allDay;
  Date *startDate;
  int duration;
  int scheduleLevel;
  RecurrenceRule *rrule;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle;
- (BOOL)isScheduledForDay:(Date *)day;
- (NSString *)details;
- (BOOL)contains:(NSString *)text;

- (NSString *)location;
- (BOOL)allDay;
- (int)duration;
- (Date *)startDate;
- (RecurrenceRule *)rrule;

- (void)setLocation:(NSString *)aLocation;
- (void)setAllDay:(BOOL)allDay;
- (void)setDuration:(int)duration;
- (void)setStartDate:(Date *)startDate;
- (void)setRRule:(RecurrenceRule *)rrule;

- (NSEnumerator *)dateEnumerator;
- (NSEnumerator *)dateRangeEnumerator;
@end

@interface Event(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic;
- (BOOL)updateICalComponent:(icalcomponent *)ic;
@end

