/* emacs buffer mode hint -*- objc -*- */

#import "Alarm.h"
#import "Date.h"
#import "Element.h"
#import "HourFormatter.h"

@implementation Alarm
- (void)deleteProperty:(icalproperty_kind)kind fromComponent:(icalcomponent *)ic
{
  icalproperty *prop = icalcomponent_get_first_property(ic, kind);
  if (prop)
      icalcomponent_remove_property(ic, prop);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:[NSString stringWithCString:icalcomponent_as_ical_string(_ic)] forKey:@"alarmComponent"];
}

- (id)initWithCoder:(NSCoder *)coder
{
  _ic = icalcomponent_new_from_string([[coder decodeObjectForKey:@"alarmComponent"] cString]);
  return self;
}

- (void)dealloc
{
  icalcomponent_free(_ic);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  if (self) {
    _element = nil;
    _ic = icalcomponent_new([self iCalComponentType]);
    if (!_ic) {
      NSLog(@"Error while creating an VALARM component");
      DESTROY(self);
    }
  }
  return self;
}

+ (id)alarm
{
  return AUTORELEASE([[Alarm alloc] init]);
}

- (NSAttributedString *)desc
{
  icalproperty *prop = icalcomponent_get_first_property(_ic, ICAL_DESCRIPTION_PROPERTY);
  if (prop)
    return AUTORELEASE([[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:icalproperty_get_description(prop)]]);
  return nil;
}

- (void)setDesc:(NSAttributedString *)desc
{
  [self deleteProperty:ICAL_DESCRIPTION_PROPERTY fromComponent:_ic];
  if (desc)
    icalcomponent_add_property(_ic, icalproperty_new_description([[desc string] UTF8String]));
}

- (NSString *)summary
{
  icalproperty *prop = icalcomponent_get_first_property(_ic, ICAL_SUMMARY_PROPERTY);
  if (!prop) {
    NSLog(@"Error : no summary property");
    return nil;
  }
  return [NSString stringWithUTF8String:icalproperty_get_summary(prop)];    
}

- (void)setSummary:(NSString *)summary
{
  [self deleteProperty:ICAL_SUMMARY_PROPERTY fromComponent:_ic];
  if (summary)
    icalcomponent_add_property(_ic, icalproperty_new_summary([summary UTF8String]));
}

- (BOOL)isAbsoluteTrigger
{
  struct icaltriggertype trigger;
  icalproperty *prop = icalcomponent_get_first_property(_ic, ICAL_TRIGGER_PROPERTY);

  if (!prop) {
    NSLog(@"Error : no trigger property");
    return NO;
  }
  trigger = icalproperty_get_trigger(prop);
  if (icaltime_is_null_time(trigger.time))
    return NO;
  return YES;
}

- (Date *)absoluteTrigger
{
  struct icaltriggertype trigger;
  icalproperty *prop = icalcomponent_get_first_property(_ic, ICAL_TRIGGER_PROPERTY);

  if (!prop) {
    NSLog(@"Error : no trigger property");
    return nil;
  }
  trigger = icalproperty_get_trigger(prop);
  return AUTORELEASE([[Date alloc] initWithICalTime:trigger.time]);
}

- (void)setAbsoluteTrigger:(Date *)date
{
  struct icaltriggertype trigger;

  [self deleteProperty:ICAL_TRIGGER_PROPERTY fromComponent:_ic];
  memset(&trigger, 0, sizeof(trigger));
  trigger.time = [date UTCICalTime];
  icalcomponent_add_property(_ic, icalproperty_new_trigger(trigger));
}

- (NSTimeInterval)relativeTrigger
{
  struct icaltriggertype trigger;
  icalproperty *prop = icalcomponent_get_first_property(_ic, ICAL_TRIGGER_PROPERTY);

  if (!prop) {
    NSLog(@"Error : no trigger property");
    return -1;
  }
  trigger = icalproperty_get_trigger(prop);
  return icaldurationtype_as_int(trigger.duration);
}

- (void)setRelativeTrigger:(NSTimeInterval)duration
{
  struct icaltriggertype trigger;

  [self deleteProperty:ICAL_TRIGGER_PROPERTY fromComponent:_ic];
  memset(&trigger, 0, sizeof(trigger));
  trigger.duration = icaldurationtype_from_int(duration);
  icalcomponent_add_property(_ic, icalproperty_new_trigger(trigger));
}

- (enum icalproperty_action)action
{
  icalproperty *prop = icalcomponent_get_first_property(_ic, ICAL_ACTION_PROPERTY);

  if (!prop) {
    NSLog(@"Error : no ACTION property");
    return -1;
  }
  return icalproperty_get_action(prop);
}

- (void)setAction:(enum icalproperty_action)action
{
  [self deleteProperty:ICAL_ACTION_PROPERTY fromComponent:_ic];
  icalcomponent_add_property(_ic, icalproperty_new_action(action));
}

- (NSString *)emailAddress
{
  icalproperty *prop = icalcomponent_get_first_property(_ic, ICAL_ATTENDEE_PROPERTY);

  if (prop)
    return [NSString stringWithUTF8String:icalproperty_get_attendee(prop)];
  return nil;
}

- (void)setEmailAddress:(NSString *)emailAddress
{
  [self deleteProperty:ICAL_ATTENDEE_PROPERTY fromComponent:_ic];
  if (emailAddress) {
    icalcomponent_add_property(_ic, icalproperty_new_attendee([emailAddress UTF8String]));
    [self setAction:ICAL_ACTION_EMAIL];
  }
}

- (NSString *)sound
{
  /* FIXME */
  return nil;
}

- (void)setSound:(NSString *)sound
{
  /* FIXME */
  if (sound) {
    [self setAction:ICAL_ACTION_AUDIO];
  }
}

- (NSURL *)url
{
  /* FIXME */
  return nil;
}

- (void)setUrl:(NSURL *)url
{
  /* FIXME */
  if (url) {
    [self setAction:ICAL_ACTION_PROCEDURE];
  }
}

- (int)repeatCount
{
  icalproperty *prop = icalcomponent_get_first_property(_ic, ICAL_REPEAT_PROPERTY);

  if (prop)
    return icalproperty_get_repeat(prop);
  return 0;
}

- (void)setRepeatCount:(int)count
{
  [self deleteProperty:ICAL_REPEAT_PROPERTY fromComponent:_ic];
  if (count > 0)
    icalcomponent_add_property(_ic, icalproperty_new_repeat(count));
}

- (NSTimeInterval)repeatInterval
{
  icalproperty *prop = icalcomponent_get_first_property(_ic, ICAL_DURATION_PROPERTY);

  if (prop)
    return icaldurationtype_as_int(icalproperty_get_duration(prop));
  return 0;
}

- (void)setRepeatInterval:(NSTimeInterval)interval
{
  [self deleteProperty:ICAL_DURATION_PROPERTY fromComponent:_ic];
  if (interval > 0)
    icalcomponent_add_property(_ic, icalproperty_new_duration(icaldurationtype_from_int(interval)));
}

- (Element *)element
{
  return _element;
}

- (void)setElement:(Element *)element
{
  _element = element;
  NSDebugLLog(@"SimpleAgenda", @"Added %@ to element %@", [self description], [element UID]);
}

- (Date *)triggerDateRelativeTo:(Date *)date
{
  return [Date dateWithTimeInterval:[self relativeTrigger] sinceDate:date];
}

- (NSString *)description
{
  if ([self isAbsoluteTrigger])
    return [NSString stringWithFormat:@"Absolute trigger set to %@ repeat %d interval %f description <%@>", [[self absoluteTrigger] description], [self repeatCount], [self repeatInterval], [self desc]];
  return [NSString stringWithFormat:@"Relative trigger delay %f repeat %d interval %f description <%@>", [self relativeTrigger], [self repeatCount], [self repeatInterval], [self desc]];
}

- (NSString *)shortDescription
{
  NSTimeInterval trigger;

  if ([self isAbsoluteTrigger])
    return [NSString stringWithFormat:_(@"Trigger on %@"), [[[self absoluteTrigger] calendarDate] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString]]];
  trigger = [self relativeTrigger];
  if (trigger >= 0)
    return [NSString stringWithFormat:_(@"Trigger %@ after the event"), [HourFormatter stringForObjectValue:[NSNumber numberWithInt:trigger]]];
  return [NSString stringWithFormat:_(@"Trigger %@ before the event"), [HourFormatter stringForObjectValue:[NSNumber numberWithInt:-trigger]]];
}

- (id)copyWithZone:(NSZone *)zone
{
  return [[Alarm allocWithZone:zone] initWithICalComponent:[self asICalComponent]];
}


- (id)initWithICalComponent:(icalcomponent *)ic
{
  if ((self = [super init])) {
    _element = nil;
    _ic = icalcomponent_new_clone(ic);
    if (!_ic) {
      NSLog(@"Error creating Alarm from iCal component");
      NSLog(@"\n\n%s", icalcomponent_as_ical_string(ic));
      DESTROY(self);
    }
  }
  return self;
}

- (icalcomponent *)asICalComponent
{
  return icalcomponent_new_clone(_ic);
}

- (int)iCalComponentType
{
  return ICAL_VALARM_COMPONENT;
}
@end
