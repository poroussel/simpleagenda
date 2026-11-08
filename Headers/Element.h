/* emacs buffer mode hint -*- objc -*- */

#import "MemoryStore.h"
#import "Date.h"
#import "ICalComponent.h"

/*
 * The CLASS property. The values are libical 3's, and are stored as they
 * are in local calendars (LocalStore) : don't change them
 */
typedef enum
{
  SAClassificationX = 10300,		/* an X- or unknown value */
  SAClassificationPublic = 10301,
  SAClassificationPrivate = 10302,
  SAClassificationConfidential = 10303,
  SAClassificationNone = 10399
} SAClassification;

@class Alarm;

@interface Element : NSObject <NSCoding>
{
  id <MemoryStore> _store;
  NSString *_uid;
  NSString *_summary;
  NSAttributedString *_text;
  SAClassification _classification;
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
- (SAClassification)classification;
- (Date *)dateStamp;

- (void)setStore:(id <MemoryStore>)store;
- (void)setText:(NSAttributedString *)text;
- (void)setSummary:(NSString *)summary;
- (void)setUID:(NSString *)uid;
- (void)setClassification:(SAClassification)classification;
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

- (id)initWithICalComponent:(ICalComponent *)component;
- (ICalComponent *)asICalComponent;
- (BOOL)updateICalComponent:(ICalComponent *)component;
- (ICalComponentKind)iCalComponentKind;
@end
