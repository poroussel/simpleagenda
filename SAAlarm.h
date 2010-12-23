/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "config.h"

extern NSString * const SAActionDisplay;
extern NSString * const SAActionEmail;
extern NSString * const SAActionProcedure;
extern NSString * const SAActionSound;

@class Date;
@class Element;

@interface SAAlarm : NSObject <NSCoding>
{
  NSAttributedString *_desc;
  NSString *_summary;
  Date *_absoluteTrigger;
  NSTimeInterval _relativeTrigger;
  NSString *_action;
  NSString *_emailaddress;
  NSString *_sound;
  NSURL *_url;
  int _repeatCount;
  NSTimeInterval _repeatInterval;
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
- (NSString *)action;
- (void)setAction:(NSString *)action;
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

- (id)initWithICalComponent:(icalcomponent *)ic;
- (icalcomponent *)asICalComponent;
- (BOOL)updateICalComponent:(icalcomponent *)ic;
- (int)iCalComponentType;
@end
