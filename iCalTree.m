#import "iCalTree.h"

@implementation iCalTree

- (id)init
{
  self = [super init];
  if (self) {
    root = icalcomponent_vanew(ICAL_VCALENDAR_COMPONENT,
			       icalproperty_new_version("1.0"),
			       icalproperty_new_prodid("-//Octets//NONSGML SimpleAgenda Calendar//EN"),
			       0);
    if (!root) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc
{
  [super dealloc];
  if (root)
    icalcomponent_free(root);
}

- (BOOL)parseString:(NSString *)string;
{
  icalcomponent *icomp;

  icomp = icalparser_parse_string([string cStringUsingEncoding:NSUTF8StringEncoding]);
  if (icomp) {
    if (root)
      icalcomponent_free(root);
    root = icomp;
    return YES;
  }
  return NO;
}

- (NSString *)iCalTreeAsString
{
  return [NSString stringWithUTF8String:icalcomponent_as_ical_string(root)];
}

- (NSSet *)events
{
  icalcomponent *ic;
  Event *ev;
  NSMutableSet *work = [NSMutableSet setWithCapacity:32];

  for (ic = icalcomponent_get_first_component(root, ICAL_VEVENT_COMPONENT); 
       ic != NULL; ic = icalcomponent_get_next_component(root, ICAL_VEVENT_COMPONENT)) {
    ev = [[Event alloc] initWithICalComponent:ic];
    if (ev)
      [work addObject:ev];
  }
  return [NSSet setWithSet:work];
}

- (icalcomponent *)componentForEvent:(Event *)evt
{
  NSString *uid = [evt UID];
  icalcomponent *ic;
  icalproperty *prop;

  for (ic = icalcomponent_get_first_component(root, ICAL_VEVENT_COMPONENT); 
       ic != NULL; ic = icalcomponent_get_next_component(root, ICAL_VEVENT_COMPONENT)) {
    prop = icalcomponent_get_first_property(ic, ICAL_UID_PROPERTY);
    if (prop) {
      if ([uid isEqual:[NSString stringWithCString:icalproperty_get_uid(prop)]])
	return ic;
    }
  }
  return NULL;
}

- (BOOL)add:(Event *)event
{
  icalcomponent *ic = icalcomponent_new(ICAL_VEVENT_COMPONENT);
  if (!ic) {
    NSLog(@"Couldn't create iCalendar component");
    return NO;
  }
  if ([event updateICalComponent:ic]) {
    icalcomponent_add_component(root, ic);
    return YES;
  }
  icalcomponent_free(ic);
  return NO;
}

- (BOOL)remove:(Event *)event
{
  icalcomponent *ic = [self componentForEvent:event];
  if (!ic) {
    NSLog(@"iCalendar component not found");
    return NO;
  }
  icalcomponent_remove_component(root, ic);
  return YES;
}

- (BOOL)update:(Event *)event
{
  icalcomponent *ic = [self componentForEvent:event];
  if (!ic) {
    NSLog(@"iCalendar component not found");
    return NO;
  }
  return [event updateICalComponent:ic];
}
@end
