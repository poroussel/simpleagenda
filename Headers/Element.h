/* emacs buffer mode hint -*- objc -*- */

#import "config.h"
#import "MemoryStore.h"
#import "Date.h"

/*
  icalproperty_class

  ICAL_CLASS_X = 10006,
  ICAL_CLASS_PUBLIC = 10007,
  ICAL_CLASS_PRIVATE = 10008,
  ICAL_CLASS_CONFIDENTIAL = 10009,
  ICAL_CLASS_NONE = 10010
*/

@class Alarm;

@interface Element : NSObject <NSCoding>
{
  id <MemoryStore> _store;
  NSString *_uid;
  NSString *_summary;
  NSAttributedString *_text;
  icalproperty_class _classification;
  Date *_stamp;
  NSMutableArray *_alarms;
  NSMutableArray *_categories;
}

+ (NSArray *)availableCategories;

- (id)initWithSummary:(NSString *)summary;
- (void)generateUID;
- (id <MemoryStore>)store;
- (NSAttributedString *)text;
- (NSString *)summary;
- (NSString *)UID;
- (icalproperty_class)classification;
- (Date *)dateStamp;

- (void)setStore:(id <MemoryStore>)store;
- (void)setText:(NSAttributedString *)text;
- (void)setSummary:(NSString *)summary;
- (void)setUID:(NSString *)uid;
- (void)setClassification:(icalproperty_class)classification;
- (void)setDateStamp:(Date *)stamp;

- (BOOL)hasAlarms;
- (NSArray *)alarms;
- (void)setAlarms:(NSArray *)alarms;
- (void)addAlarm:(Alarm *)alarm;
- (void)removeAlarm:(Alarm *)alarm;
- (Date *)nextActivationDate;

- (NSArray *)categories;
- (void)setCategories:(NSArray *)categories;
- (void)addCategory:(NSString *)category;
- (void)removeCategory:(NSString *)category;
- (BOOL)inCategory:(NSString *)category;

- (id)initWithICalComponent:(icalcomponent *)ic;
- (icalcomponent *)asICalComponent;
- (void)deleteProperty:(icalproperty_kind)kind fromComponent:(icalcomponent *)ic;
- (BOOL)updateICalComponent:(icalcomponent *)ic;
- (int)iCalComponentType;
@end
