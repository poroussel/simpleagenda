#import <string.h>
#import "ICalComponent.h"
#import "Date+ICal.h"
#import "RecurrenceRule+ICal.h"

static icalcomponent_kind icalKind(ICalComponentKind kind)
{
  switch (kind) {
  case ICalVCalendar:
    return ICAL_VCALENDAR_COMPONENT;
  case ICalVEvent:
    return ICAL_VEVENT_COMPONENT;
  case ICalVTodo:
    return ICAL_VTODO_COMPONENT;
  case ICalVAlarm:
    return ICAL_VALARM_COMPONENT;
  default:
    return ICAL_NO_COMPONENT;
  }
}

/*
 * The libical kind of a property name. X- names all have the kind
 * ICAL_X_PROPERTY : xname is set to the name to look for
 */
static icalproperty_kind propertyKind(NSString *name, const char **xname)
{
  const char *cname = [name UTF8String];

  *xname = NULL;
  if (cname == NULL)
    return ICAL_NO_PROPERTY;
  if (!strncmp(cname, "X-", 2)) {
    *xname = cname;
    return ICAL_X_PROPERTY;
  }
  return icalproperty_string_to_kind(cname);
}

static BOOL hasName(icalproperty *prop, const char *xname)
{
  const char *name;

  if (xname == NULL)
    return YES;
  name = icalproperty_get_x_name(prop);
  return name && !strcmp(name, xname);
}

static icalproperty *firstProperty(icalcomponent *ic, NSString *name)
{
  const char *xname;
  icalproperty_kind kind = propertyKind(name, &xname);
  icalproperty *prop;

  if (kind == ICAL_NO_PROPERTY)
    return NULL;
  for (prop = icalcomponent_get_first_property(ic, kind); prop; prop = icalcomponent_get_next_property(ic, kind))
    if (hasName(prop, xname))
      return prop;
  return NULL;
}

/* All the properties with that name, in order */
static NSArray *allProperties(icalcomponent *ic, NSString *name)
{
  NSMutableArray *props = [NSMutableArray array];
  const char *xname;
  icalproperty_kind kind = propertyKind(name, &xname);
  icalproperty *prop;

  if (kind == ICAL_NO_PROPERTY)
    return props;
  for (prop = icalcomponent_get_first_property(ic, kind); prop; prop = icalcomponent_get_next_property(ic, kind))
    if (hasName(prop, xname))
      [props addObject:[NSValue valueWithPointer:prop]];
  return props;
}

static NSString *textOf(icalproperty *prop)
{
  icalvalue *value = icalproperty_get_value(prop);
  const char *text;

  if (value == NULL)
    return nil;
  if (icalvalue_isa(value) == ICAL_TEXT_VALUE)
    text = icalvalue_get_text(value);
  else
    text = icalproperty_get_value_as_string(prop);
  return text ? [NSString stringWithUTF8String:text] : nil;
}

static icalproperty *newTextProperty(NSString *name, NSString *text)
{
  const char *xname;
  const char *ctext = [text UTF8String];
  icalproperty_kind kind = propertyKind(name, &xname);
  icalvalue_kind vkind;
  icalvalue *value;
  icalproperty *prop;

  if (kind == ICAL_X_PROPERTY) {
    prop = icalproperty_new_x(ctext);
    icalproperty_set_x_name(prop, xname);
    return prop;
  }
  if (kind == ICAL_NO_PROPERTY)
    return NULL;
  vkind = icalproperty_kind_to_value_kind(kind);
  /* libical writes the X and NONE enumerated values as an empty value */
  if (*ctext == 0 && kind == ICAL_CLASS_PROPERTY)
    return icalproperty_new_class(ICAL_CLASS_NONE);
  if (*ctext == 0 && kind == ICAL_STATUS_PROPERTY)
    return icalproperty_new_status(ICAL_STATUS_NONE);
  if (vkind == ICAL_TEXT_VALUE)
    value = icalvalue_new_text(ctext);
  else
    value = icalvalue_new_from_string(vkind, ctext);
  if (value == NULL) {
    NSLog(@"Invalid value %@ for property %@", text, name);
    return NULL;
  }
  prop = icalproperty_new(kind);
  icalproperty_set_value(prop, value);
  return prop;
}

/*
 * libical reads a DATE-TIME with a TZID parameter without its timezone.
 * Look it up : in the VTIMEZONE components of the calendar, then in
 * libical's built-in timezones, by TZID or by location (America/New_York).
 * A TZID that can't be found gives a local time, as before
 */
static struct icaltimetype withTimezone(icalproperty *prop, struct icaltimetype time)
{
  icalparameter *param;
  icalcomponent *root;
  icaltimezone *zone = NULL;
  const char *tzid;

  if (time.is_date || time.zone != NULL || icaltime_is_null_time(time))
    return time;
  param = icalproperty_get_first_parameter(prop, ICAL_TZID_PARAMETER);
  if (param == NULL || (tzid = icalparameter_get_tzid(param)) == NULL)
    return time;
  for (root = icalproperty_get_parent(prop); root && icalcomponent_get_parent(root);
       root = icalcomponent_get_parent(root))
    ;
  if (root)
    zone = icalcomponent_get_timezone(root, tzid);
  if (zone == NULL)
    zone = icaltimezone_get_builtin_timezone_from_tzid(tzid);
  if (zone == NULL)
    zone = icaltimezone_get_builtin_timezone(tzid);
  if (zone == NULL)
    return time;
  return icaltime_set_timezone(&time, zone);
}

static struct icaltimetype timeOf(icalproperty *prop)
{
  switch (icalproperty_isa(prop)) {
  case ICAL_DTSTART_PROPERTY:
    return withTimezone(prop, icalproperty_get_dtstart(prop));
  case ICAL_DTEND_PROPERTY:
    return withTimezone(prop, icalproperty_get_dtend(prop));
  case ICAL_DTSTAMP_PROPERTY:
    return icalproperty_get_dtstamp(prop);
  case ICAL_DUE_PROPERTY:
    return withTimezone(prop, icalproperty_get_due(prop));
  case ICAL_TRIGGER_PROPERTY:
    return icalproperty_get_trigger(prop).time;
  default:
    return withTimezone(prop, icalvalue_get_datetime(icalproperty_get_value(prop)));
  }
}

static icalproperty *newTimeProperty(icalproperty_kind kind, struct icaltimetype time)
{
  struct icaltriggertype trigger;

  switch (kind) {
  case ICAL_DTSTART_PROPERTY:
    return icalproperty_new_dtstart(time);
  case ICAL_DTEND_PROPERTY:
    return icalproperty_new_dtend(time);
  case ICAL_DTSTAMP_PROPERTY:
    return icalproperty_new_dtstamp(time);
  case ICAL_DUE_PROPERTY:
    return icalproperty_new_due(time);
  case ICAL_TRIGGER_PROPERTY:
    memset(&trigger, 0, sizeof(trigger));
    trigger.time = time;
    return icalproperty_new_trigger(trigger);
  default:
    NSLog(@"Property %s doesn't hold a date", icalproperty_kind_to_string(kind));
    return NULL;
  }
}

@implementation ICalComponent
- (id)initWithICalComponent:(icalcomponent *)ic parent:(ICalComponent *)parent
{
  if ((self = [super init])) {
    _ic = ic;
    _parent = RETAIN(parent);
  }
  return self;
}

+ (ICalComponent *)componentWithString:(NSString *)string
{
  icalcomponent *ic;

  if (string == nil)
    return nil;
  ic = icalparser_parse_string([string UTF8String]);
  if (ic == NULL)
    return nil;
  return AUTORELEASE([[ICalComponent alloc] initWithICalComponent:ic parent:nil]);
}

+ (ICalComponent *)componentWithKind:(ICalComponentKind)kind
{
  icalcomponent *ic;

  if (icalKind(kind) == ICAL_NO_COMPONENT)
    return nil;
  ic = icalcomponent_new(icalKind(kind));
  if (ic == NULL)
    return nil;
  return AUTORELEASE([[ICalComponent alloc] initWithICalComponent:ic parent:nil]);
}

- (void)dealloc
{
  if (_parent)
    RELEASE(_parent);
  else if (_ic)
    icalcomponent_free(_ic);
  [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
  return [[ICalComponent allocWithZone:zone] initWithICalComponent:icalcomponent_new_clone(_ic) parent:nil];
}

- (ICalComponentKind)kind
{
  switch (icalcomponent_isa(_ic)) {
  case ICAL_VCALENDAR_COMPONENT:
    return ICalVCalendar;
  case ICAL_VEVENT_COMPONENT:
    return ICalVEvent;
  case ICAL_VTODO_COMPONENT:
    return ICalVTodo;
  case ICAL_VALARM_COMPONENT:
    return ICalVAlarm;
  default:
    return ICalOtherComponent;
  }
}

- (NSString *)stringValue
{
  const char *string = icalcomponent_as_ical_string(_ic);

  return string ? [NSString stringWithUTF8String:string] : nil;
}

- (void)removeErrors
{
  icalcomponent_strip_errors(_ic);
}

- (NSArray *)componentsOfKind:(ICalComponentKind)kind
{
  NSMutableArray *components = [NSMutableArray array];
  icalcomponent_kind ickind = icalKind(kind);
  icalcomponent *ic;

  if (ickind == ICAL_NO_COMPONENT)
    return components;
  for (ic = icalcomponent_get_first_component(_ic, ickind); ic; ic = icalcomponent_get_next_component(_ic, ickind))
    [components addObject:AUTORELEASE([[ICalComponent alloc] initWithICalComponent:ic parent:self])];
  return components;
}

- (void)addComponent:(ICalComponent *)component
{
  NSAssert(component->_parent == nil, @"The component already has a parent");
  icalcomponent_add_component(_ic, component->_ic);
  component->_parent = RETAIN(self);
}

- (void)removeComponent:(ICalComponent *)component
{
  NSAssert(icalcomponent_get_parent(component->_ic) == _ic, @"Not a child of this component");
  icalcomponent_remove_component(_ic, component->_ic);
  DESTROY(component->_parent);
}

- (BOOL)hasProperty:(NSString *)name
{
  return firstProperty(_ic, name) != NULL;
}

- (void)removeProperty:(NSString *)name
{
  icalproperty *prop = firstProperty(_ic, name);

  if (prop) {
    icalcomponent_remove_property(_ic, prop);
    icalproperty_free(prop);
  }
}

- (void)removeAllProperties:(NSString *)name
{
  NSEnumerator *enumerator = [allProperties(_ic, name) objectEnumerator];
  NSValue *value;

  while ((value = [enumerator nextObject])) {
    icalcomponent_remove_property(_ic, [value pointerValue]);
    icalproperty_free([value pointerValue]);
  }
}

- (NSString *)textForProperty:(NSString *)name
{
  icalproperty *prop = firstProperty(_ic, name);

  return prop ? textOf(prop) : nil;
}

- (NSArray *)textsForProperty:(NSString *)name
{
  NSMutableArray *texts = [NSMutableArray array];
  NSEnumerator *enumerator = [allProperties(_ic, name) objectEnumerator];
  NSValue *value;
  NSString *text;

  while ((value = [enumerator nextObject]))
    if ((text = textOf([value pointerValue])))
      [texts addObject:text];
  return texts;
}

- (void)setText:(NSString *)text forProperty:(NSString *)name
{
  icalproperty *prop;

  [self removeProperty:name];
  if (text && (prop = newTextProperty(name, text)))
    icalcomponent_add_property(_ic, prop);
}

- (Date *)dateForProperty:(NSString *)name
{
  icalproperty *prop = firstProperty(_ic, name);
  struct icaltimetype time;

  if (prop == NULL)
    return nil;
  time = timeOf(prop);
  if (icalproperty_isa(prop) == ICAL_TRIGGER_PROPERTY && icaltime_is_null_time(time))
    return nil;
  return AUTORELEASE([[Date alloc] initWithICalTime:time]);
}

- (void)setUTCTime:(struct icaltimetype)time forProperty:(NSString *)name
{
  const char *xname;
  icalproperty *prop;

  [self removeProperty:name];
  if ((prop = newTimeProperty(propertyKind(name, &xname), time)))
    icalcomponent_add_property(_ic, prop);
}

- (void)setDate:(Date *)date forProperty:(NSString *)name
{
  if (date)
    [self setUTCTime:[date UTCICalTime] forProperty:name];
  else
    [self setUTCTime:icaltime_null_time() forProperty:name];
}

- (void)setDate:(Date *)date plusSeconds:(NSTimeInterval)seconds forProperty:(NSString *)name
{
  [self setUTCTime:icaltime_add([date UTCICalTime], icaldurationtype_from_int(seconds)) forProperty:name];
}

- (NSTimeInterval)secondsFromProperty:(NSString *)from toProperty:(NSString *)to
{
  icalproperty *pfrom = firstProperty(_ic, from);
  icalproperty *pto = firstProperty(_ic, to);
  struct icaltimetype start, end;

  if (pfrom == NULL || pto == NULL)
    return 0;
  start = timeOf(pfrom);
  end = timeOf(pto);
  /* icaltime_subtract() ignores timezones : subtract UTC times */
  if (start.zone && end.zone) {
    start = icaltime_convert_to_zone(start, icaltimezone_get_utc_timezone());
    end = icaltime_convert_to_zone(end, icaltimezone_get_utc_timezone());
  }
  return icaldurationtype_as_int(icaltime_subtract(end, start));
}

- (BOOL)getDuration:(NSTimeInterval *)duration forProperty:(NSString *)name
{
  icalproperty *prop = firstProperty(_ic, name);

  if (prop == NULL)
    return NO;
  if (icalproperty_isa(prop) == ICAL_TRIGGER_PROPERTY)
    *duration = icaldurationtype_as_int(icalproperty_get_trigger(prop).duration);
  else
    *duration = icaldurationtype_as_int(icalproperty_get_duration(prop));
  return YES;
}

- (void)setDuration:(NSTimeInterval)duration forProperty:(NSString *)name
{
  const char *xname;
  icalproperty_kind kind = propertyKind(name, &xname);
  struct icaltriggertype trigger;
  icalproperty *prop;

  [self removeProperty:name];
  if (kind == ICAL_TRIGGER_PROPERTY) {
    memset(&trigger, 0, sizeof(trigger));
    trigger.duration = icaldurationtype_from_int(duration);
    prop = icalproperty_new_trigger(trigger);
  } else if (kind == ICAL_DURATION_PROPERTY)
    prop = icalproperty_new_duration(icaldurationtype_from_int(duration));
  else {
    NSLog(@"Property %@ doesn't hold a duration", name);
    return;
  }
  icalcomponent_add_property(_ic, prop);
}

- (RecurrenceRule *)ruleForProperty:(NSString *)name
{
  icalproperty *prop = firstProperty(_ic, name);

  if (prop == NULL)
    return nil;
  return AUTORELEASE([[RecurrenceRule alloc] initWithICalRRule:icalproperty_get_rrule(prop)]);
}

- (void)setRule:(RecurrenceRule *)rule forProperty:(NSString *)name
{
  [self removeProperty:name];
  if (rule)
    icalcomponent_add_property(_ic, icalproperty_new_rrule([rule iCalRRule]));
}
@end
