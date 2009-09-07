#import <Foundation/Foundation.h>
#import "Date.h"
#import "Element.h"

@implementation Element
-(void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_summary forKey:@"title"];
  [coder encodeObject:[_text string] forKey:@"descriptionText"];
  [coder encodeObject:_uid forKey:@"uid"];
  [coder encodeInt:_classification forKey:@"classification"];
  if (_stamp)
    [coder encodeObject:_stamp forKey:@"dtstamp"];
}

-(id)initWithCoder:(NSCoder *)coder
{
  _summary = [[coder decodeObjectForKey:@"title"] retain];
  _text = [[NSAttributedString alloc] initWithString:[coder decodeObjectForKey:@"descriptionText"]];
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
  return self;
}

- (id)init
{
  self = [super init];
  if (self) {
    [self generateUID];
    [self setDateStamp:[Date now]];
    [self setClassification: ICAL_CLASS_PUBLIC];
  }
  return self;
}

- (id)initWithSummary:(NSString *)summary
{
  self = [self init];
  if (self)
    [self setSummary:summary];
  return self;
}

- (void)dealloc
{
  [super dealloc];
  RELEASE(_summary);
  RELEASE(_text);
  RELEASE(_store);
  RELEASE(_uid);
  RELEASE(_stamp);
}

- (id <MemoryStore>)store
{
  return _store;
}

- (void)setStore:(id <MemoryStore>)store
{
  ASSIGN(_store, store);
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
  Date *now = [Date now];
  static Date *lastDate;
  static int counter;

  if (!lastDate)
    ASSIGNCOPY(lastDate, now);
  else {
    if (![lastDate compareTime:now])
      counter++;
    else {
      ASSIGNCOPY(lastDate, now);
      counter = 0;
    }
  }
  [self setUID:[NSString stringWithFormat:@"SimpleAgenda-%@-%d-%@", [now description], counter, [[NSHost currentHost] address]]];
}

- (NSString *)UID
{
  return _uid;
}

- (void)setUID:(NSString *)aUid;
{
  ASSIGNCOPY(_uid, aUid);
}

- (icalproperty_class)classification
{
  return _classification;
}

- (void)setClassification:(icalproperty_class)classification
{
  if (classification < ICAL_CLASS_X || classification > ICAL_CLASS_NONE) {
    NSLog(@"Wrong classification value %d, change it to ICAL_CLASS_PUBLIC", classification);
    classification = ICAL_CLASS_PUBLIC;
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

- (id)initWithICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;

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
  prop = icalcomponent_get_first_property(ic, ICAL_DTSTAMP_PROPERTY);
  if (prop)
    [self setClassification:icalproperty_get_class(prop)];
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
  icalproperty *prop;
  prop = icalcomponent_get_first_property(ic, kind);
  if (prop)
      icalcomponent_remove_property(ic, prop);
}

- (BOOL)updateICalComponent:(icalcomponent *)ic
{
  [self deleteProperty:ICAL_UID_PROPERTY fromComponent:ic];
  icalcomponent_add_property(ic, icalproperty_new_uid([[self UID] cString]));
  [self deleteProperty:ICAL_SUMMARY_PROPERTY fromComponent:ic];
  if ([self summary])
    icalcomponent_add_property(ic, icalproperty_new_summary([[self summary] UTF8String]));
  [self deleteProperty:ICAL_DESCRIPTION_PROPERTY fromComponent:ic];
  if ([self text])
    icalcomponent_add_property(ic, icalproperty_new_description([[[self text] string] UTF8String]));
  [self deleteProperty:ICAL_DTSTAMP_PROPERTY fromComponent:ic];
  icalcomponent_add_property(ic, icalproperty_new_dtstamp([_stamp iCalTime]));  
  [self deleteProperty:ICAL_CLASS_PROPERTY fromComponent:ic];
  icalcomponent_add_property(ic, icalproperty_new_class([self classification]));
  return YES;
}

- (int)iCalComponentType
{
  NSLog(@"Shouldn't be used");
  return -1;
}
@end
