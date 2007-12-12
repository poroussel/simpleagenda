/* emacs buffer mode hint -*- objc -*- */

#import <ical.h>
#import "AgendaStore.h"
#import "Date.h"

enum classificationType
{
  CT_NONE = 0, 
  CT_PUBLIC, 
  CT_PRIVATE, 
  CT_CONFIDENTIAL 
};

@interface Element : NSObject <NSCoding>
{
  id <MemoryStore> _store;
  NSString *_uid;
  NSString *_summary;
  NSAttributedString *_text;
  enum classificationType _classification;
  Date *_stamp;
}

- (id)initWithSummary:(NSString *)summary;
- (void)generateUID;
- (id <MemoryStore>)store;
- (NSAttributedString *)text;
- (NSString *)summary;
- (NSString *)UID;
- (enum classificationType)classification;
- (Date *)dateStamp;

- (void)setStore:(id <MemoryStore>)store;
- (void)setText:(NSAttributedString *)text;
- (void)setSummary:(NSString *)summary;
- (void)setUID:(NSString *)uid;
- (void)setClassification:(enum classificationType)classification;
- (void)setDateStamp:(Date *)stamp;

- (id)initWithICalComponent:(icalcomponent *)ic;
- (icalcomponent *)asICalComponent;
- (void)deleteProperty:(icalproperty_kind)kind fromComponent:(icalcomponent *)ic;
- (BOOL)updateICalComponent:(icalcomponent *)ic;
- (int)iCalComponentType;
@end
