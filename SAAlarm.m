/* emacs buffer mode hint -*- objc -*- */

#import "SAAlarm.h"
#import "Date.h"
#import "Element.h"

NSString * const SAActionDisplay = @"DISPLAY";
NSString * const SAActionEmail = @"EMAIL";
NSString * const SAActionProcedure = @"PROCEDURE";
NSString * const SAActionSound = @"AUDIO";

@implementation SAAlarm
- (void)dealloc
{
  DESTROY(_text);
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
  _text = nil;
  _absoluteTrigger = nil;
  _relativeTrigger = 0;
  _emailaddress = nil;
  _sound = nil;
  _url = nil;
  _element = nil;
  return self;
}

+ (id)alarm
{
  return AUTORELEASE([[SAAlarm alloc] init]);
}

- (NSAttributedString *)text
{
  return _text;
}

- (void)setText:(NSAttributedString *)text
{
  ASSIGN(_text, text);
}

- (BOOL)isAbsoluteTrigger
{
  return _absoluteTrigger != nil;
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
  ASSIGN(_action, action);
}

- (NSString *)emailAddress
{
  return _emailaddress;
}

- (void)setEmailAddress:(NSString *)emailAddress
{
  ASSIGN(_emailaddress, emailAddress);
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
  ASSIGN(_sound, sound);
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
  ASSIGN(_url, url);
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

- (Element *)element
{
  return _element;
}

- (void)setElement:(Element *)element
{
  _element = element;
  NSLog(@"Added %@ to element %@", [self description], [element UID]);
}

- (Date *)triggerDateRelativeTo:(Date *)date
{
  return [Date dateWithTimeInterval:_relativeTrigger sinceDate:date];
}

- (NSString *)description
{
  if ([self isAbsoluteTrigger])
    return [NSString stringWithFormat:@"Absolute trigger set to %@ repeat %d interval %f with text <%@> action %@", [_absoluteTrigger description], _repeatCount, _repeatInterval, _text, _action];
  return [NSString stringWithFormat:@"Relative trigger delay %f repeat %d interval %f with text <%@> action %@", _relativeTrigger, _repeatCount, _repeatInterval, _text, _action];
}

- (id)initWithICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;
  struct icaltriggertype trigger;

  self = [self init];
  if (self == nil)
    return nil;
  prop = icalcomponent_get_first_property(ic, ICAL_ACTION_PROPERTY);
  if (!prop) {
    NSLog(@"No action defined, alarm disabled");
    goto init_error;
  }
  switch (icalproperty_get_action(prop)) {
  case ICAL_ACTION_X:
  case ICAL_ACTION_DISPLAY:
    [self setAction:SAActionDisplay];
    break;
  case ICAL_ACTION_AUDIO:
    [self setAction:SAActionSound];
    break;
  case ICAL_ACTION_EMAIL:
    [self setAction:SAActionEmail];
    break;
  case ICAL_ACTION_PROCEDURE:
    [self setAction:SAActionProcedure];
    break;
  default:
    NSLog(@"No action defined, alarm disabled");
    goto init_error;
  }
  prop = icalcomponent_get_first_property(ic, ICAL_DESCRIPTION_PROPERTY);
  if (prop)
    [self setText:AUTORELEASE([[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:icalproperty_get_description(prop)]])];
  prop = icalcomponent_get_first_property(ic, ICAL_TRIGGER_PROPERTY);
  if (!prop) {
    NSLog(@"No trigger defined, alarm disabled");
    goto init_error;
  }
  trigger = icalproperty_get_trigger(prop);
  if (icaltime_is_null_time(trigger.time))
    [self setRelativeTrigger:icaldurationtype_as_int(trigger.duration)];
  else
    [self setAbsoluteTrigger:AUTORELEASE([[Date alloc] initWithICalTime:trigger.time])];
  prop = icalcomponent_get_first_property(ic, ICAL_REPEAT_PROPERTY);
  if (prop)
    [self setRepeatCount:icalproperty_get_repeat(prop)];
  return self;

 init_error:
  NSLog(@"Error creating Alarm from iCal component");
  [self release];
  return nil;
}

- (icalcomponent *)asICalComponent
{
  return NULL;
}

- (BOOL)updateICalComponent:(icalcomponent *)ic
{
  return NO;
}

- (int)iCalComponentType
{
  return ICAL_VALARM_COMPONENT;
}
@end
