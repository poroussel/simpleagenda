#import "iCalTree.h"
#import "Event.h"
#import "Task.h"

@implementation iCalTree
- (id)init
{
  if ((self = [super init])) {
    root = icalcomponent_vanew(ICAL_VCALENDAR_COMPONENT, icalproperty_new_version("1.0"),
			       icalproperty_new_prodid("-//Octets//NONSGML SimpleAgenda Calendar//EN"), 0);
    if (!root)
      DESTROY(self);
  }
  return self;
}

- (void)dealloc
{
  icalcomponent_free(root);
  [super dealloc];
}

- (BOOL)parseString:(NSString *)string;
{
  icalcomponent *icomp;

  if (string == nil) {
    NSLog(@"No string to parse");
    return NO;
  }
  icomp = icalparser_parse_string([string UTF8String]);
  if (icomp) {
    icalcomponent_free(root);
    root = icomp;
    return YES;
  }
  return NO;
}

- (BOOL)parseData:(NSData *)data
{
  return [self parseString:[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];
}

- (NSString *)iCalTreeAsString
{
  /* OGo workaround  ? */
  icalproperty *prop = icalcomponent_get_first_property(root, ICAL_METHOD_PROPERTY);
  if (prop)
    icalcomponent_remove_property(root, prop);
  icalcomponent_strip_errors(root);
  return [NSString stringWithUTF8String:icalcomponent_as_ical_string(root)];
}

- (NSData *)iCalTreeAsData;
{
  return [[self iCalTreeAsString] dataUsingEncoding:NSUTF8StringEncoding];
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
    if (ev) {
      [work addObject:ev];
      [ev release];
    }
  }
  for (ic = icalcomponent_get_first_component(root, ICAL_VTODO_COMPONENT);
       ic != NULL; ic = icalcomponent_get_next_component(root, ICAL_VTODO_COMPONENT)) {
    task = [[Task alloc] initWithICalComponent:ic];
    if (task) {
      [work addObject:task];
      [task release];
    }
  }
  return [NSSet setWithSet:work];
}

- (icalcomponent *)componentForEvent:(Element *)elt
{
  icalcomponent *ic;
  icalproperty *prop;
  NSString *uid = [elt UID];
  int type = [elt iCalComponentType];

  for (ic = icalcomponent_get_first_component(root, type);
       ic != NULL; ic = icalcomponent_get_next_component(root, type)) {
    prop = icalcomponent_get_first_property(ic, ICAL_UID_PROPERTY);
    if (prop && [uid isEqual:[NSString stringWithCString:icalproperty_get_uid(prop)]])
	return ic;
  }
  NSLog(@"iCalendar component not found for %@", [elt description]);
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
  if (!ic)
    return NO;
  icalcomponent_remove_component(root, ic);
  return YES;
}

- (BOOL)update:(Element *)elt
{
  icalcomponent *ic = [self componentForEvent:elt];
  if (!ic)
    return NO;
  return [elt updateICalComponent:ic];
}
@end
