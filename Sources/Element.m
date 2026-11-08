#import <Foundation/Foundation.h>
#import "Date.h"
#import "Element.h"
#import "Alarm.h"

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
  [coder encodeObject:[self UID] forKey:@"uid"];
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
    _classification = SAClassificationPublic;
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
  _classification = SAClassificationPublic;
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
  [self setUID:[NSString stringWithFormat:@"SimpleAgenda-%@", [[NSUUID UUID] UUIDString]]];
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

- (SAClassification)classification
{
  return _classification;
}

- (void)setClassification:(SAClassification)classification
{
  if (classification < SAClassificationX || classification > SAClassificationNone) {
    NSLog(@"Wrong classification value %d, change it to SAClassificationPublic", classification);
    _classification = SAClassificationPublic;
    return;
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
  _alarms = [NSMutableArray new];
  [_alarms addObjectsFromArray:alarms];
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
  [_alarms removeObject:alarm];
  [alarm setElement:nil];
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

/* The CLASS values, as libical writes them */
static NSString *classificationName(SAClassification classification)
{
  switch (classification) {
  case SAClassificationPublic:
    return @"PUBLIC";
  case SAClassificationPrivate:
    return @"PRIVATE";
  case SAClassificationConfidential:
    return @"CONFIDENTIAL";
  default:
    return @"";
  }
}

static SAClassification classificationNamed(NSString *name)
{
  if ([name isEqualToString:@"PUBLIC"])
    return SAClassificationPublic;
  if ([name isEqualToString:@"PRIVATE"])
    return SAClassificationPrivate;
  if ([name isEqualToString:@"CONFIDENTIAL"])
    return SAClassificationConfidential;
  return SAClassificationX;
}

- (id)initWithICalComponent:(ICalComponent *)component
{
  NSEnumerator *enumerator;
  ICalComponent *subc;
  NSString *text;
  Alarm *alarm;

  self = [self init];
  if (self == nil)
    return nil;
  if (![component hasProperty:@"UID"]) {
    NSLog(@"No UID");
    goto init_error;
  }
  [self setUID:[component textForProperty:@"UID"]];
  if (![component hasProperty:@"SUMMARY"]) {
    NSLog(@"No summary");
    goto init_error;
  }
  [self setSummary:[component textForProperty:@"SUMMARY"]];
  if ([component hasProperty:@"DESCRIPTION"])
    [self setText:AUTORELEASE([[NSAttributedString alloc] initWithString:[component textForProperty:@"DESCRIPTION"]])];
  if ([component hasProperty:@"DTSTAMP"])
    [self setDateStamp:[component dateForProperty:@"DTSTAMP"]];
  if ([component hasProperty:@"CLASS"])
    [self setClassification:classificationNamed([component textForProperty:@"CLASS"])];
  if ((text = [component textForProperty:@"CATEGORIES"]))
    [self setCategories:[text componentsSeparatedByString:@","]];

  enumerator = [[component componentsOfKind:ICalVAlarm] objectEnumerator];
  while ((subc = [enumerator nextObject])) {
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

- (ICalComponent *)asICalComponent
{
  ICalComponent *component = [ICalComponent componentWithKind:[self iCalComponentKind]];

  if (!component) {
    NSLog(@"Couldn't create iCalendar component");
    return nil;
  }
  if (![self updateICalComponent:component])
    return nil;
  return component;
}

- (BOOL)updateICalComponent:(ICalComponent *)component
{
  NSEnumerator *enumerator;
  ICalComponent *subc;
  Alarm *alarm;

  [component setText:[self UID] forProperty:@"UID"];
  [component setText:[self summary] forProperty:@"SUMMARY"];
  [component setText:[[self text] string] forProperty:@"DESCRIPTION"];
  [component setDate:_stamp forProperty:@"DTSTAMP"];
  [component setText:classificationName([self classification]) forProperty:@"CLASS"];
  if ([[self categories] count] > 0)
    [component setText:[[self categories] componentsJoinedByString:@","] forProperty:@"CATEGORIES"];
  else
    [component removeProperty:@"CATEGORIES"];

  enumerator = [[component componentsOfKind:ICalVAlarm] objectEnumerator];
  while ((subc = [enumerator nextObject]))
    [component removeComponent:subc];
  enumerator = [[self alarms] objectEnumerator];
  while ((alarm = [enumerator nextObject]))
    [component addComponent:[alarm asICalComponent]];
  return YES;
}

- (ICalComponentKind)iCalComponentKind
{
  NSLog(@"Shouldn't be used");
  return ICalOtherComponent;
}
@end
