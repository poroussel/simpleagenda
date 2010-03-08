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
+ (void)registered
{
  NSDictionary *defs = [NSDictionary dictionaryWithObjectsAndKeys:[[NSColor purpleColor] description], ST_COLOR,
				     [[NSColor whiteColor] description], ST_TEXT_COLOR,
				     [NSNumber numberWithBool:NO], ST_RW,
				     [NSNumber numberWithBool:YES], ST_DISPLAY,
				     [NSNumber numberWithBool:YES], ST_ENABLED,
				     @"ABStore", ST_CLASS,
				     nil, nil];
  [[ConfigManager globalConfig] setObject:defs forKey:_(@"birthdays")];
  [[StoreManager globalManager] addStoreNamed:_(@"birthdays")];
}

+ (NSString *)storeTypeName
{
  return @"Address book store";
}

- (void)loadData
{
  ADAddressBook *ab;
  ADPerson *person;
  NSArray *people;
  NSEnumerator *enumerator;
  id value;
  Date *date;
  Event *event;
  RecurrenceRule *rrule;

  ab = [ADAddressBook sharedAddressBook];
  people = [ab people];
  enumerator = [people objectEnumerator];
  rrule = [[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceYearly];
  while ((person = [enumerator nextObject])) {
    value = [person valueForProperty:ADBirthdayProperty];
    if (value && [value class] == [NSCalendarDate class]) {
      date = [Date today];
      [date setYear:[value yearOfCommonEra]];
      [date setMonth:[value monthOfYear]];
      [date setDay:[value dayOfMonth]];
      event = [[Event alloc] initWithStartDate:date duration:0 title:[person screenName]];
      [event setAllDay:YES];
      [event setRRule:rrule];
      [self add:event];
      [event release];
    }
  }
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
