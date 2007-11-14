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
    _classification = CT_PUBLIC;
  return self;
}

- (id)initWithSummary:(NSString *)summary
{
  self = [self init];
  if (self) {
    [self setSummary:summary];
    [self generateUID];
  }
  return self;
}

- (void)dealloc
{
  [super dealloc];
  RELEASE(_summary);
  RELEASE(_text);
  RELEASE(_store);
  RELEASE(_uid);
}

- (id <MemoryStore>)store
{
  return _store;
}
- (void)setStore:(id <AgendaStore>)store
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
  [self setUID:[NSString stringWithFormat:@"SimpleAgenda-%@%d-%@", 
			 [now description], 
			 counter,
			 [[NSHost currentHost] name]]];
}
- (NSString *)UID
{
  return _uid;
}
- (void)setUID:(NSString *)aUid;
{
  ASSIGNCOPY(_uid, aUid);
}

- (enum classificationType)classification
{
  return _classification;
}
- (void)setClassification:(enum classificationType)classification
{
  _classification = classification;
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
  [self setSummary:[NSString stringWithCString:icalproperty_get_summary(prop) encoding:NSUTF8StringEncoding]];
  prop = icalcomponent_get_first_property(ic, ICAL_DESCRIPTION_PROPERTY);
  if (prop) {
    NSAttributedString *as = [[NSAttributedString alloc] initWithString:[NSString stringWithCString:icalproperty_get_description(prop) encoding:NSUTF8StringEncoding]];
    [self setText:as];
    [as release];
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
- (BOOL)updateICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;

  prop = icalcomponent_get_first_property(ic, ICAL_UID_PROPERTY);
  if (!prop) {
    prop = icalproperty_new_uid([[self UID] cString]);
    icalcomponent_add_property(ic, prop);
  }
  prop = icalcomponent_get_first_property(ic, ICAL_SUMMARY_PROPERTY);
  if (!prop) {
    prop = icalproperty_new_summary([[self summary] UTF8String]);
    icalcomponent_add_property(ic, prop);
  } else
    icalproperty_set_summary(prop, [[self summary] UTF8String]);
  if ([self text] != nil) {
    prop = icalcomponent_get_first_property(ic, ICAL_DESCRIPTION_PROPERTY);
    if (!prop) {
      prop = icalproperty_new_description([[[self text] string] UTF8String]);
      icalcomponent_add_property(ic, prop);
    } else
      icalproperty_set_description(prop, [[[self text] string] UTF8String]);
  }
  return YES;
}
- (int)iCalComponentType
{
  NSLog(@"Shouldn't be used");
  return -1;
}
@end
