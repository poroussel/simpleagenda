#import "iCalTree.h"
#import "Event.h"
#import "Task.h"

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

- (NSSet *)components
{
  icalcomponent *ic;
  Event *ev;
  Task *task;
  NSMutableSet *work = [NSMutableSet setWithCapacity:32];

  for (ic = icalcomponent_get_first_component(root, ICAL_VEVENT_COMPONENT); 
       ic != NULL; ic = icalcomponent_get_next_component(root, ICAL_VEVENT_COMPONENT)) {
    ev = [[Event alloc] initWithICalComponent:ic];
    if (ev)
      [work addObject:ev];
  }
  for (ic = icalcomponent_get_first_component(root, ICAL_VTODO_COMPONENT); 
       ic != NULL; ic = icalcomponent_get_next_component(root, ICAL_VTODO_COMPONENT)) {
    task = [[Task alloc] initWithICalComponent:ic];
    if (task)
      [work addObject:task];
  }
  return [NSSet setWithSet:work];
}

- (icalcomponent *)componentForEvent:(Element *)elt
{
  NSString *uid = [elt UID];
  icalcomponent *ic;
  icalproperty *prop;
  int type = [elt iCalComponentType];

  for (ic = icalcomponent_get_first_component(root, type); 
       ic != NULL; ic = icalcomponent_get_next_component(root, type)) {
    prop = icalcomponent_get_first_property(ic, ICAL_UID_PROPERTY);
    if (prop) {
      if ([uid isEqual:[NSString stringWithCString:icalproperty_get_uid(prop)]])
	return ic;
    }
  }
  return NULL;
}

- (BOOL)add:(Element *)elt
{
  icalcomponent *ic = [elt asICalComponent];
  if (!ic)
    return NO;
  icalcomponent_add_component(root, ic);
  return YES;
}

- (BOOL)remove:(Element *)elt
{
  icalcomponent *ic = [self componentForEvent:elt];
  if (!ic) {
    NSLog(@"iCalTree remove : iCalendar component not found");
    return NO;
  }
  icalcomponent_remove_component(root, ic);
  return YES;
}

- (BOOL)update:(Element *)elt
{
  icalcomponent *ic = [self componentForEvent:elt];
  if (!ic) {
    NSLog(@"iCalTree update : iCalendar component not found");
    return NO;
  }
  return [elt updateICalComponent:ic];
}
@end
