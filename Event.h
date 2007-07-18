/* emacs buffer mode hint -*- objc -*- */

#import "Date.h"
#import "AgendaStore.h"

enum intervalType
{
  RI_NONE = 0, 
  RI_DAILY, 
  RI_WEEKLY, 
  RI_MONTHLY, 
  RI_YEARLY
};

@interface Event : NSObject
{
  id <AgendaStore> _store;
  NSString *_location;
  BOOL _allDay;
  NSString *_uid;
  NSString *title;
  NSAttributedString *descriptionText;
  Date *startDate;
  Date *endDate;
  int duration;
  enum intervalType interval;
  int frequency;
  int scheduleLevel;
}

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle;
- (BOOL)isScheduledBetweenDay:(Date *)start andDay:(Date *)end;
- (NSString *)details;
- (void)generateUID;

- (id <AgendaStore>)store;
- (NSString *)location;
- (BOOL)allDay;
- (NSAttributedString *)descriptionText;
- (NSString *)title;
- (int)duration;
- (int)frequency;
- (Date *)startDate;
- (Date *)endDate;
- (int)interval;
- (NSString *)UID;

- (void)setStore:(id <AgendaStore>)store;
- (void)setLocation:(NSString *)aLocation;
- (void)setAllDay:(BOOL)allDay;
- (void)setDescriptionText:(NSAttributedString *)descriptionText;
- (void)setTitle:(NSString *)title;
- (void)setDuration:(int)duration;
- (void)setFrequency:(int)frequency;
- (void)setStartDate:(Date *)startDate;
- (void)setEndDate:(Date *)endDate;
- (void)setInterval:(int)interval;
- (void)setUID:(NSString *)uid;
@end

@interface Event(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic;
- (BOOL)updateICalComponent:(icalcomponent *)ic;
@end

