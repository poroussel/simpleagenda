/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "config.h"

@class Date;
@class Element;

@interface Alarm : NSObject <NSCoding>
{
  icalcomponent *_ic;
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
- (enum icalproperty_action)action;
- (void)setAction:(enum icalproperty_action)action;
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

- (id)initWithICalComponent:(icalcomponent *)ic;
- (icalcomponent *)asICalComponent;
- (int)iCalComponentType;
@end
