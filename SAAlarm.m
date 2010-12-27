/* emacs buffer mode hint -*- objc -*- */

#import "SAAlarm.h"
#import "Date.h"
#import "Element.h"

NSString * const SAActionDisplay = @"DISPLAY";
NSString * const SAActionEmail = @"EMAIL";
NSString * const SAActionProcedure = @"PROCEDURE";
NSString * const SAActionSound = @"AUDIO";

@implementation SAAlarm
- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_action forKey:@"action"];
  [coder encodeInt:_repeatCount forKey:@"repeatCount"];
  [coder encodeDouble:_relativeTrigger forKey:@"relativeTrigger"];
  [coder encodeDouble:_repeatInterval forKey:@"repeatInterval"];
  if (_summary)
    [coder encodeObject:_summary forKey:@"summary"];
  if (_desc)
    [coder encodeObject:[_desc string] forKey:@"description"];
  if (_absoluteTrigger)
    [coder encodeObject:_absoluteTrigger forKey:@"absoluteTrigger"];
  if (_emailaddress)
    [coder encodeObject:_emailaddress forKey:@"emailAddress"];
  if (_sound)
    [coder encodeObject:_sound forKey:@"sound"];
  if (_url)
    [coder encodeObject:_url forKey:@"url"];
}

- (id)initWithCoder:(NSCoder *)coder
{
  _action = [[coder decodeObjectForKey:@"action"] retain];
  _repeatCount = [coder decodeIntForKey:@"repeatCount"];
  _relativeTrigger = [coder decodeDoubleForKey:@"relativeTrigger"];
  _repeatInterval = [coder decodeDoubleForKey:@"repeatInterval"];
  if ([coder containsValueForKey:@"summary"])
    _summary = [[coder decodeObjectForKey:@"summary"] retain];
  if ([coder containsValueForKey:@"description"])
    _desc = [[NSAttributedString alloc] initWithString:[coder decodeObjectForKey:@"description"]];
  if ([coder containsValueForKey:@"absoluteTrigger"])
    _absoluteTrigger = [[coder decodeObjectForKey:@"absoluteTrigger"] retain];
  if ([coder containsValueForKey:@"emailAddress"])
    _emailaddress = [[coder decodeObjectForKey:@"emailAddress"] retain];
  if ([coder containsValueForKey:@"sound"])
    _sound = [[coder decodeObjectForKey:@"sound"] retain];
  if ([coder containsValueForKey:@"url"])
    _url = [[coder decodeObjectForKey:@"url"] retain];
  return self;
}

- (void)dealloc
{
  DESTROY(_desc);
  DESTROY(_summary);
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
  _desc = nil;
  _summary = nil;
  _absoluteTrigger = nil;
  _relativeTrigger = 0;
  _repeatInterval = 0;
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

- (NSAttributedString *)desc
{
  return _desc;
}

- (void)setDesc:(NSAttributedString *)desc
{
  ASSIGN(_desc, desc);
}

- (NSString *)summary
{
  return _summary;
}

- (void)setSummary:(NSString *)summary
{
  ASSIGN(_summary, summary);
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
  NSDebugLog(@"Added %@ to element %@", [self description], [element UID]);
}

- (Date *)triggerDateRelativeTo:(Date *)date
{
  return [Date dateWithTimeInterval:_relativeTrigger sinceDate:date];
}

- (NSString *)description
{
  if ([self isAbsoluteTrigger])
    return [NSString stringWithFormat:@"Absolute trigger set to %@ repeat %d interval %f description <%@> action %@", [_absoluteTrigger description], _repeatCount, _repeatInterval, _desc, _action];
  return [NSString stringWithFormat:@"Relative trigger delay %f repeat %d interval %f description <%@> action %@", _relativeTrigger, _repeatCount, _repeatInterval, _desc, _action];
}

- (id)initWithICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;
  struct icaltriggertype trigger;

  self = [self init];
  if (self == nil)
    return nil;

  /* ACTION */
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
    /* ATTENDEE */
    prop = icalcomponent_get_first_property(ic, ICAL_ATTENDEE_PROPERTY);
    if (!prop) {
      NSLog(@"No email address, alarm disabled");
      goto init_error;
    }
    [self setEmailAddress:[NSString stringWithUTF8String:icalproperty_get_attendee(prop)]];    
    /* SUMMARY */
    prop = icalcomponent_get_first_property(ic, ICAL_SUMMARY_PROPERTY);
    if (!prop) {
      NSLog(@"No summary, alarm disabled");
      goto init_error;
    }
    [self setSummary:[NSString stringWithUTF8String:icalproperty_get_summary(prop)]];    
    break;
  case ICAL_ACTION_PROCEDURE:
    [self setAction:SAActionProcedure];
    break;
  default:
    NSLog(@"No action defined, alarm disabled");
    goto init_error;
  }

  /* TRIGGER */
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

  /* DESCRIPTION */
  prop = icalcomponent_get_first_property(ic, ICAL_DESCRIPTION_PROPERTY);
  if (prop)
    [self setDesc:AUTORELEASE([[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:icalproperty_get_description(prop)]])];

  /* REPEAT */
  prop = icalcomponent_get_first_property(ic, ICAL_REPEAT_PROPERTY);
  if (prop) {
    [self setRepeatCount:icalproperty_get_repeat(prop)];
    /* If REPEAT is present, DURATION must be here too */
    prop = icalcomponent_get_first_property(ic, ICAL_DURATION_PROPERTY);
    if (!prop) {
      NSLog(@"REPEAT without DURATION, alarm disabled");
      goto init_error;
    }
    [self setRepeatInterval:icaldurationtype_as_int(icalproperty_get_duration(prop))];
  }
  return self;

 init_error:
  NSLog(@"Error creating Alarm from iCal component");
  NSLog(@"\n\n%s", icalcomponent_as_ical_string(ic));
  [self release];
  return nil;
}

- (icalcomponent *)asICalComponent
{
  icalcomponent *ic = icalcomponent_new([self iCalComponentType]);
  if (!ic) {
    NSLog(@"Couldn't create iCalendar component");
    return NULL;
  }
  if (![self updateICalComponent:ic]) {
    icalcomponent_free(ic);
    return NULL;
  }
  return ic;
}

- (void)deleteProperty:(icalproperty_kind)kind fromComponent:(icalcomponent *)ic
{
  icalproperty *prop = icalcomponent_get_first_property(ic, kind);
  if (prop)
      icalcomponent_remove_property(ic, prop);
}

- (BOOL)updateICalComponent:(icalcomponent *)ic
{
  struct icaltriggertype trigger;

  [self deleteProperty:ICAL_ACTION_PROPERTY fromComponent:ic];
  if ([[self action] isEqualToString:SAActionDisplay])
    icalcomponent_add_property(ic, icalproperty_new_action(ICAL_ACTION_DISPLAY));
  else if ([[self action] isEqualToString:SAActionEmail])
    icalcomponent_add_property(ic, icalproperty_new_action(ICAL_ACTION_EMAIL));
  else if ([[self action] isEqualToString:SAActionProcedure])
    icalcomponent_add_property(ic, icalproperty_new_action(ICAL_ACTION_PROCEDURE));
  else if ([[self action] isEqualToString:SAActionSound])
    icalcomponent_add_property(ic, icalproperty_new_action(ICAL_ACTION_AUDIO));
  [self deleteProperty:ICAL_SUMMARY_PROPERTY fromComponent:ic];
  icalcomponent_add_property(ic, icalproperty_new_summary([[self summary] UTF8String]));
  [self deleteProperty:ICAL_TRIGGER_PROPERTY fromComponent:ic];
  memset(&trigger, 0, sizeof(trigger));
  if ([self isAbsoluteTrigger])
    trigger.time = [[self absoluteTrigger] iCalTime];
  else
    trigger.duration = icaldurationtype_from_int([self relativeTrigger]);
  icalcomponent_add_property(ic, icalproperty_new_trigger(trigger));
  [self deleteProperty:ICAL_DESCRIPTION_PROPERTY fromComponent:ic];
  if ([self desc])
    icalcomponent_add_property(ic, icalproperty_new_description([[[self desc] string] UTF8String]));
  [self deleteProperty:ICAL_REPEAT_PROPERTY fromComponent:ic];
  [self deleteProperty:ICAL_DURATION_PROPERTY fromComponent:ic];
  if ([self repeatCount] > 0) {
    icalcomponent_add_property(ic, icalproperty_new_repeat([self repeatCount]));
    icalcomponent_add_property(ic, icalproperty_new_duration(icaldurationtype_from_int([self repeatInterval])));
  }
  return YES;
}

- (int)iCalComponentType
{
  return ICAL_VALARM_COMPONENT;
}
@end
