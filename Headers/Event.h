/* emacs buffer mode hint -*- objc -*- */

#import "Date.h"
#import "Element.h"
#import "RecurrenceRule.h"

@interface Event : Element
{
  NSString *_location;
  BOOL _allDay;
  Date *_startDate;
  int _duration;
  BOOL _sticky;
  RecurrenceRule *_rrule;
  /* -hasOccurrences cache : the rule and start it was computed for */
  RecurrenceRule *_checkedRule;
  Date *_checkedStart;
  BOOL _hasOccurrences;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle;
/* An event without duration is scheduled on the day it starts */
- (BOOL)isScheduledForDay:(Date *)day;
/* In seconds from the start of day. Empty for an event without duration */
- (NSRange)intersectionWithDay:(Date *)day;
- (NSString *)details;
- (BOOL)contains:(NSString *)text;

- (NSString *)location;
- (BOOL)allDay;
- (int)duration;
- (Date *)startDate;
- (RecurrenceRule *)rrule;
- (BOOL)sticky;

- (void)setLocation:(NSString *)aLocation;
- (void)setAllDay:(BOOL)allDay;
- (void)setDuration:(int)duration;
- (void)setStartDate:(Date *)startDate;
- (void)setRRule:(RecurrenceRule *)rrule;
- (void)setSticky:(BOOL)sticky;

/* The start date of each occurrence, nil if the event doesn't repeat */
- (NSEnumerator *)occurrenceEnumerator;
/* NO for a recurrent event whose rule gives no occurrence */
- (BOOL)hasOccurrences;
@end

@interface Event(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic;
- (BOOL)updateICalComponent:(icalcomponent *)ic;
@end

