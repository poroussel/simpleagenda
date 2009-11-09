/* emacs buffer mode hint -*- objc -*- */

#import "SAAlarm.h"

NSString *SAActionDisplay = @"DISPLAY";
NSString *SAActionEmail = @"EMAIL";
NSString *SAActionProcedure = @"PROCEDURE";
NSString *SAActionSound = @"AUDIO";

@implementation SAAlarm
- (void)dealloc
{
  DESTROY(_absoluteTrigger);
  DESTROY(_action);
  DESTROY(_emailaddress);
  DESTROY(_sound);
  DESTROY(_url);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  _absoluteTrigger = nil;
  _relativeTrigger = 0;
  _emailaddress = nil;
  _sound = nil;
  _url = nil;
  return self;
}

+ (id)alarm
{
  return AUTORELEASE([[SAAlarm alloc] init]);
}

- (Date *)absoluteTrigger
{
  return _absoluteTrigger;
}

- (void)setAbsoluteTrigger:(Date *)trigger
{
  ASSIGNCOPY(_absoluteTrigger, trigger);
  _relativeTrigger = 0;
}

- (NSTimeInterval)relativeTrigger
{
  return _relativeTrigger;
}

- (void)setRelativeTrigger:(NSTimeInterval)trigger
{
  _relativeTrigger = trigger;
  DESTROY(_absoluteTrigger);
}

- (NSString *)action
{
  return _action;
}

- (void)setAction:(NSString *)action
{
  ASSIGNCOPY(_action, action);
}

- (NSString *)emailAddress
{
  return _emailaddress;
}

- (void)setEmailAddress:(NSString *)emailAddress
{
  ASSIGNCOPY(_emailaddress, emailAddress);
  DESTROY(_sound);
  DESTROY(_url);
  [self setAction:SAActionEmail];
}

- (NSString *)sound
{
  return _sound;
}

- (void)setSound:(NSString *)sound
{
  ASSIGNCOPY(_sound, sound);
  DESTROY(_emailaddress);
  DESTROY(_url);
  [self setAction:SAActionSound];
}

- (NSURL *)url
{
  return _url;
}

- (void)setUrl:(NSURL *)url
{
  ASSIGNCOPY(_url, url);
  DESTROY(_emailaddress);
  DESTROY(_sound);
  [self setAction:SAActionProcedure];
}

- (int)repeatCount
{
  return _repeatCount;
}

- (void)setRepeatCount:(int)count
{
  _repeatCount = count;
}

- (NSTimeInterval)repeatInterval
{
  return _repeatInterval;
}

- (void)setRepeatInterval:(NSTimeInterval)interval
{
  _repeatInterval = interval;
}

- (Date *)triggerDateRelativeTo:(Date *)date
{
  return [Date dateWithTimeInterval:_relativeTrigger sinceDate:date];
}
@end
