/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "ICalComponent.h"

@class Date;
@class Element;

/* The ACTION property */
typedef enum
{
  SAAlarmActionNone = -1,	/* no ACTION */
  SAAlarmActionOther = 0,	/* an X- or unknown action */
  SAAlarmActionAudio,
  SAAlarmActionDisplay,
  SAAlarmActionEmail,
  SAAlarmActionProcedure
} SAAlarmAction;

@interface Alarm : NSObject <NSCoding>
{
  ICalComponent *_component;
  Element *_element;
}

+ (id)alarm;
- (NSAttributedString *)desc;
- (void)setDesc:(NSAttributedString *)desc;
- (NSString *)summary;
- (void)setSummary:(NSString *)summary;
- (BOOL)isAbsoluteTrigger;
- (Date *)absoluteTrigger;
- (void)setAbsoluteTrigger:(Date *)trigger;
- (NSTimeInterval)relativeTrigger;
- (void)setRelativeTrigger:(NSTimeInterval)trigger;
- (SAAlarmAction)action;
- (void)setAction:(SAAlarmAction)action;
- (NSString *)emailAddress;
- (void)setEmailAddress:(NSString *)emailAddress;
- (NSString *)sound;
- (void)setSound:(NSString *)sound;
- (NSURL *)url;
- (void)setUrl:(NSURL *)url;
- (int)repeatCount;
- (void)setRepeatCount:(int)count;
- (NSTimeInterval)repeatInterval;
- (void)setRepeatInterval:(NSTimeInterval)interval;
- (Element *)element;
- (void)setElement:(Element *)element;
- (Date *)triggerDateRelativeTo:(Date *)date;
- (NSString *)shortDescription;

- (id)initWithICalComponent:(ICalComponent *)component;
- (ICalComponent *)asICalComponent;
- (ICalComponentKind)iCalComponentKind;
@end
