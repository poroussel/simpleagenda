#import <Foundation/Foundation.h>
#import <AppKit/NSColor.h>
#import <Addresses/Addresses.h>
#import "MemoryStore.h"
#import "ConfigManager.h"
#import "StoreManager.h"
#import "Event.h"
#import "RecurrenceRule.h"
#import "defines.h"

@interface ABStore : MemoryStore
{
}
@end

@implementation ABStore
- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjectsAndKeys:[[NSColor purpleColor] description], ST_COLOR,
		       [[NSColor whiteColor] description], ST_TEXT_COLOR,
		       [NSNumber numberWithBool:NO], ST_RW,
		       [NSNumber numberWithBool:YES], ST_DISPLAY,
		       [NSNumber numberWithBool:YES], ST_ENABLED,
		       nil, nil];
}

+ (NSString *)storeName
{
  return _(@"My address book");
}

+ (NSString *)storeTypeName
{
  return @"Address book store";
}

- (void)loadData
{
  ADPerson *person;
  NSEnumerator *enumerator;
  id value;
  Date *date;
  Event *event;
  RecurrenceRule *rrule;

  enumerator = [[[ADAddressBook sharedAddressBook] people] objectEnumerator];
  rrule = [[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceYearly];
  while ((person = [enumerator nextObject])) {
    value = [person valueForProperty:ADBirthdayProperty];
    if (value && [value isMemberOfClass:[NSCalendarDate class]]) {
      date = [Date today];
      [date setYear:[value yearOfCommonEra]];
      [date setMonth:[(NSCalendarDate *)value monthOfYear]];
      [date setDay:[(NSCalendarDate *)value dayOfMonth]];
      event = [[Event alloc] initWithStartDate:date duration:0 title:[person screenName]];
      [event setAllDay:YES];
      [event setRRule:rrule];
      [event setText:AUTORELEASE([[NSAttributedString alloc] initWithString:_(@"Birthday")])];
      [self add:event];
      [event release];
    }
  }
  NSLog(@"ABStore : found %d contact(s) with a birthdate", [[self events] count]);
  [rrule release];
}

- (id)initWithName:(NSString *)name
{
  self = [super initWithName:name];
  if (self) {
    [self loadData];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseChanged:) name:ADDatabaseChangedExternallyNotification object:nil];
  }
  return self;
}

- (void)databaseChanged:(NSNotification *)not
{
  [_data removeAllObjects];
  [self loadData];
}

- (BOOL)writable
{
  return NO;
}
@end
