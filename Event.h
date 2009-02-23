/* emacs buffer mode hint -*- objc -*- */

#import "Date.h"
#import "Element.h"

enum intervalType
{
  RI_NONE = 0, 
  RI_DAILY, 
  RI_WEEKLY, 
  RI_MONTHLY, 
  RI_YEARLY
};

@interface Event : Element
{
  NSString *_location;
  BOOL _allDay;
  Date *startDate;
  Date *endDate;
  int duration;
  enum intervalType interval;
  int frequency;
  int scheduleLevel;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle;
- (BOOL)isScheduledForDay:(Date *)day;
- (NSString *)details;
- (BOOL)contains:(NSString *)text;

- (NSString *)location;
- (BOOL)allDay;
- (int)duration;
- (int)frequency;
- (Date *)startDate;
- (Date *)endDate;
- (int)interval;

- (void)setLocation:(NSString *)aLocation;
- (void)setAllDay:(BOOL)allDay;
- (void)setDuration:(int)duration;
- (void)setFrequency:(int)frequency;
- (void)setStartDate:(Date *)startDate;
- (void)setEndDate:(Date *)endDate;
- (void)setInterval:(int)interval;
@end

@interface Event(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic;
- (BOOL)updateICalComponent:(icalcomponent *)ic;
@end

