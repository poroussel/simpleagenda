/* emacs buffer mode hint -*- objc -*- */

#import "Alarm.h"
#import "Date.h"
#import "Element.h"
#import "HourFormatter.h"

/* The ACTION values, as libical writes them */
static NSString *actionNames[] = {@"", @"AUDIO", @"DISPLAY", @"EMAIL", @"PROCEDURE"};

@implementation Alarm
- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:[_component stringValue] forKey:@"alarmComponent"];
}

- (id)initWithCoder:(NSCoder *)coder
{
  _component = RETAIN([ICalComponent componentWithString:[coder decodeObjectForKey:@"alarmComponent"]]);
  return self;
}

- (void)dealloc
{
  RELEASE(_component);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  if (self) {
    _element = nil;
    _component = RETAIN([ICalComponent componentWithKind:[self iCalComponentKind]]);
    if (!_component) {
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
  if ([_component hasProperty:@"DESCRIPTION"])
    return AUTORELEASE([[NSAttributedString alloc] initWithString:[_component textForProperty:@"DESCRIPTION"]]);
  return nil;
}

- (void)setDesc:(NSAttributedString *)desc
{
  [_component setText:[desc string] forProperty:@"DESCRIPTION"];
}

- (NSString *)summary
{
  if (![_component hasProperty:@"SUMMARY"]) {
    NSLog(@"Error : no summary property");
    return nil;
  }
  return [_component textForProperty:@"SUMMARY"];
}

- (void)setSummary:(NSString *)summary
{
  [_component setText:summary forProperty:@"SUMMARY"];
}

- (BOOL)isAbsoluteTrigger
{
  if (![_component hasProperty:@"TRIGGER"]) {
    NSLog(@"Error : no trigger property");
    return NO;
  }
  return [_component dateForProperty:@"TRIGGER"] != nil;
}

- (Date *)absoluteTrigger
{
  if (![_component hasProperty:@"TRIGGER"]) {
    NSLog(@"Error : no trigger property");
    return nil;
  }
  return [_component dateForProperty:@"TRIGGER"];
}

- (void)setAbsoluteTrigger:(Date *)date
{
  [_component setDate:date forProperty:@"TRIGGER"];
}

- (NSTimeInterval)relativeTrigger
{
  NSTimeInterval trigger;

  if (![_component getDuration:&trigger forProperty:@"TRIGGER"]) {
    NSLog(@"Error : no trigger property");
    return -1;
  }
  return trigger;
}

- (void)setRelativeTrigger:(NSTimeInterval)duration
{
  [_component setDuration:duration forProperty:@"TRIGGER"];
}

- (SAAlarmAction)action
{
  NSString *action = [_component textForProperty:@"ACTION"];
  SAAlarmAction a;

  if (![_component hasProperty:@"ACTION"]) {
    NSLog(@"Error : no ACTION property");
    return SAAlarmActionNone;
  }
  for (a = SAAlarmActionAudio; a <= SAAlarmActionProcedure; a++)
    if ([action isEqualToString:actionNames[a]])
      return a;
  return SAAlarmActionOther;
}

- (void)setAction:(SAAlarmAction)action
{
  if (action < SAAlarmActionAudio || action > SAAlarmActionProcedure) {
    NSLog(@"Wrong alarm action %d", action);
    return;
  }
  [_component setText:actionNames[action] forProperty:@"ACTION"];
}

- (NSString *)emailAddress
{
  return [_component textForProperty:@"ATTENDEE"];
}

- (void)setEmailAddress:(NSString *)emailAddress
{
  [_component setText:emailAddress forProperty:@"ATTENDEE"];
  if (emailAddress)
    [self setAction:SAAlarmActionEmail];
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
    [self setAction:SAAlarmActionAudio];
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
    [self setAction:SAAlarmActionProcedure];
  }
}

- (int)repeatCount
{
  return [[_component textForProperty:@"REPEAT"] intValue];
}

- (void)setRepeatCount:(int)count
{
  [_component setText:count > 0 ? [NSString stringWithFormat:@"%d", count] : nil forProperty:@"REPEAT"];
}

- (NSTimeInterval)repeatInterval
{
  NSTimeInterval interval;

  if ([_component getDuration:&interval forProperty:@"DURATION"])
    return interval;
  return 0;
}

- (void)setRepeatInterval:(NSTimeInterval)interval
{
  if (interval > 0)
    [_component setDuration:interval forProperty:@"DURATION"];
  else
    [_component removeProperty:@"DURATION"];
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
  return [[Alarm allocWithZone:zone] initWithICalComponent:_component];
}

- (id)initWithICalComponent:(ICalComponent *)component
{
  if ((self = [super init])) {
    _element = nil;
    _component = [component copy];
    if (!_component) {
      NSLog(@"Error creating Alarm from iCal component");
      NSLog(@"\n\n%@", [component stringValue]);
      DESTROY(self);
    }
  }
  return self;
}

- (ICalComponent *)asICalComponent
{
  return AUTORELEASE([_component copy]);
}

- (ICalComponentKind)iCalComponentKind
{
  return ICalVAlarm;
}
@end
