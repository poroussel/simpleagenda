#import <Foundation/Foundation.h>
#import "Date.h"
#import "Element.h"
#import "Alarm.h"
#import "NSString+SimpleAgenda.h"

static NSArray *availableCategories;

@implementation Element
+ (void)initialize
{
  if (self == [Element class]) {
    availableCategories = [[NSArray alloc] initWithObjects:_(@"None"),
					   _(@"Anniversary"),
					   _(@"Appointment"),
					   _(@"Business"),
					   _(@"Congress"),
					   _(@"Education"),
					   _(@"Holiday"),
					   _(@"Idea"),
					   _(@"Meeting"),
					   _(@"Miscellaneous"),
					   _(@"Personal"),
					   _(@"Phone call"),
					   _(@"Sick day"),
					   _(@"Travel"),
					   _(@"Vacation"),
					   nil];
  }
}

+ (NSArray *)availableCategories
{
  return availableCategories;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_summary forKey:@"title"];
  if (_text)
    [coder encodeObject:[_text string] forKey:@"descriptionText"];
  [coder encodeObject:_uid forKey:@"uid"];
  [coder encodeInt:_classification forKey:@"classification"];
  if (_stamp)
    [coder encodeObject:_stamp forKey:@"dtstamp"];
  [coder encodeObject:_categories forKey:@"categories"];
  [coder encodeObject:_alarms forKey:@"alarms"];
}

- (id)initWithCoder:(NSCoder *)coder
{
  _summary = [[coder decodeObjectForKey:@"title"] retain];
  if ([coder containsValueForKey:@"descriptionText"])
    _text = [[NSAttributedString alloc] initWithString:[coder decodeObjectForKey:@"descriptionText"]];
  else
    _text = nil;
  if ([coder containsValueForKey:@"uid"])
    _uid = [[coder decodeObjectForKey:@"uid"] retain];
  else
    [self generateUID];
  if ([coder containsValueForKey:@"classification"])
    _classification = [coder decodeIntForKey:@"classification"];
  else
    _classification = ICAL_CLASS_PUBLIC;
  if ([coder containsValueForKey:@"dtstamp"])
    _stamp = [[coder decodeObjectForKey:@"dtstamp"] retain];
  else
    _stamp = nil;
  if ([coder containsValueForKey:@"categories"])
    _categories = [[coder decodeObjectForKey:@"categories"] retain];
  else
    _categories = [NSMutableArray new];
  [self setAlarms:[coder decodeObjectForKey:@"alarms"]];
  return self;
}

- (id)init
{
  if (!(self = [super init]))
    return nil;
  _alarms = [NSMutableArray new];
  _categories = [NSMutableArray new];
  _classification = ICAL_CLASS_PUBLIC;
  _text = nil;
  ASSIGNCOPY(_stamp, [Date now]);
  return self;
}

- (id)initWithSummary:(NSString *)summary
{
  if ((self = [self init]))
    [self setSummary:summary];
  return self;
}

- (void)dealloc
{
  RELEASE(_summary);
  RELEASE(_text);
  RELEASE(_uid);
  RELEASE(_stamp);
  RELEASE(_alarms);
  RELEASE(_categories);
  [super dealloc];
}

- (id <MemoryStore>)store
{
  return _store;
}

- (void)setStore:(id <MemoryStore>)store
{
  _store = store;
}

- (NSAttributedString *)text
{
  return _text;
}

- (void)setText:(NSAttributedString *)text
{
  ASSIGN(_text, text);
}

- (NSString *)summary
{
  return _summary;
}

- (void)setSummary:(NSString *)summary
{
  ASSIGN(_summary, summary);
}

- (void)generateUID
{
  [self setUID:[NSString stringWithFormat:@"SimpleAgenda-%@", [NSString uuid]]];
}

- (NSString *)UID
{
  if (!_uid)
    [self generateUID];
  return _uid;
}

- (void)setUID:(NSString *)aUid;
{
  ASSIGN(_uid, aUid);
}

- (icalproperty_class)classification
{
  return _classification;
}

- (void)setClassification:(icalproperty_class)classification
{
  if (classification < ICAL_CLASS_X || classification > ICAL_CLASS_NONE) {
    NSLog(@"Wrong classification value %d, change it to ICAL_CLASS_PUBLIC", classification);
    _classification = ICAL_CLASS_PUBLIC;
  }
  _classification = classification;
}

- (Date *)dateStamp
{
  return _stamp;
}

- (void)setDateStamp:(Date *)stamp;
{
  ASSIGNCOPY(_stamp, stamp);
}

- (BOOL)hasAlarms
{
  return [_alarms count] > 0;
}

- (NSArray *)alarms
{
  return [NSArray arrayWithArray:_alarms];
}

- (void)setAlarms:(NSArray *)alarms
{
  NSEnumerator *enumerator;
  Alarm *alarm;

  DESTROY(_alarms);
  ASSIGNCOPY(_alarms, alarms);
  enumerator = [_alarms objectEnumerator];
  while ((alarm = [enumerator nextObject]))
    [alarm setElement:self];
}

- (void)addAlarm:(Alarm *)alarm
{
  [alarm setElement:self];
  [_alarms addObject:alarm];
}

- (void)removeAlarm:(Alarm *)alarm
{
  /* FIXME : do something */
}

- (Date *)nextActivationDate
{
  return nil;
}

- (NSArray *)categories
{
  return [NSArray arrayWithArray:_categories];
}
- (void)setCategories:(NSArray *)categories
{
  [_categories setArray:categories];
}
- (void)addCategory:(NSString *)category
{
  if (![_categories containsObject:category])
    [_categories addObject:category];
}
- (void)removeCategory:(NSString *)category
{
  if ([_categories containsObject:category])
    [_categories removeObject:category];
}
- (BOOL)inCategory:(NSString *)category
{
  return [_categories containsObject:category];
}

- (id)initWithICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;
  icalcomponent *subc;
  Alarm *alarm;

  self = [self init];
  if (self == nil)
    return nil;
  prop = icalcomponent_get_first_property(ic, ICAL_UID_PROPERTY);
  if (!prop) {
    NSLog(@"No UID");
    goto init_error;
  }
  [self setUID:[NSString stringWithCString:icalproperty_get_uid(prop)]];    
  prop = icalcomponent_get_first_property(ic, ICAL_SUMMARY_PROPERTY);
  if (!prop) {
    NSLog(@"No summary");
    goto init_error;
  }
  [self setSummary:[NSString stringWithUTF8String:icalproperty_get_summary(prop)]];
  prop = icalcomponent_get_first_property(ic, ICAL_DESCRIPTION_PROPERTY);
  if (prop)
    [self setText:AUTORELEASE([[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:icalproperty_get_description(prop)]])];
  prop = icalcomponent_get_first_property(ic, ICAL_DTSTAMP_PROPERTY);
  if (prop)
    [self setDateStamp:AUTORELEASE([[Date alloc] initWithICalTime:icalproperty_get_dtstamp(prop)])];
  prop = icalcomponent_get_first_property(ic, ICAL_CLASS_PROPERTY);
  if (prop)
    [self setClassification:icalproperty_get_class(prop)];
  prop = icalcomponent_get_first_property(ic, ICAL_CATEGORIES_PROPERTY);
  if (prop)
    [self setCategories:[[NSString stringWithUTF8String:icalproperty_get_categories(prop)] componentsSeparatedByString:@","]];

  subc = icalcomponent_get_first_component(ic, ICAL_VALARM_COMPONENT);
  for (; subc != NULL; subc = icalcomponent_get_next_component(ic, ICAL_VALARM_COMPONENT)) {
    alarm = [[Alarm alloc] initWithICalComponent:subc];
    if (alarm) {
      [self addAlarm:alarm];
      RELEASE(alarm);
    }
  }
  return self;

 init_error:
  NSLog(@"Error creating Element from iCal component");
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
  NSEnumerator *enumerator;
  Alarm *alarm;
  icalcomponent *subc;

  [self deleteProperty:ICAL_UID_PROPERTY fromComponent:ic];
  icalcomponent_add_property(ic, icalproperty_new_uid([[self UID] cString]));
  [self deleteProperty:ICAL_SUMMARY_PROPERTY fromComponent:ic];
  if ([self summary])
    icalcomponent_add_property(ic, icalproperty_new_summary([[self summary] UTF8String]));
  [self deleteProperty:ICAL_DESCRIPTION_PROPERTY fromComponent:ic];
  if ([self text])
    icalcomponent_add_property(ic, icalproperty_new_description([[[self text] string] UTF8String]));
  [self deleteProperty:ICAL_DTSTAMP_PROPERTY fromComponent:ic];
  icalcomponent_add_property(ic, icalproperty_new_dtstamp([_stamp UTCICalTime]));  
  [self deleteProperty:ICAL_CLASS_PROPERTY fromComponent:ic];
  icalcomponent_add_property(ic, icalproperty_new_class([self classification]));
  [self deleteProperty:ICAL_CATEGORIES_PROPERTY fromComponent:ic];
  if ([[self categories] count] > 0)
    icalcomponent_add_property(ic, icalproperty_new_categories([[[self categories] componentsJoinedByString:@","] UTF8String]));

  subc = icalcomponent_get_first_component(ic, ICAL_VALARM_COMPONENT);
  for (; subc != NULL; subc = icalcomponent_get_next_component(ic, ICAL_VALARM_COMPONENT))
    icalcomponent_remove_component(ic, subc);
  enumerator = [[self alarms] objectEnumerator];
  while ((alarm = [enumerator nextObject])) {
    subc = [alarm asICalComponent];
    icalcomponent_add_component(ic, subc);
    icalcomponent_free(subc);
  }
  return YES;
}

- (int)iCalComponentType
{
  NSLog(@"Shouldn't be used");
  return -1;
}
@end
