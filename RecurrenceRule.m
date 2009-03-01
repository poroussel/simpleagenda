#import "RecurrenceRule.h"

@interface NSRecurrenceEnumerator : NSEnumerator
{
  icalrecur_iterator *iterator;
}
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start;
@end
@implementation NSRecurrenceEnumerator
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start;
{
  self = [super init];
  if (self != nil) {
    /*
     * It's OK to use Date iCaltime: here as timezone modifications
     * only affect datetimes, not dates
     */
    iterator = icalrecur_iterator_new([rule iCalRRule],  [start iCalTime]);
  }
  return self;
}
- (id)nextObject
{
  struct icaltimetype next;
  
  next = icalrecur_iterator_next(iterator);
  if (icaltime_is_null_time(next))
    return nil;
  return AUTORELEASE([[Date alloc] initWithICalTime:next]);
}
- (void)dealloc
{
  icalrecur_iterator_free(iterator);
  [super dealloc];
}
@end

@implementation RecurrenceRule
- (id)init
{
  self = [super init];
  if (self)
    icalrecurrencetype_clear(&recur);
  return self;
}
- (id)initWithFrequency:(recurrenceFrequency)frequency until:(Date *)endDate
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  NSAssert([endDate isDate], @"Works on dates");
  self = [self init];
  if (self) {
    /*
     * It's OK to use Date iCaltime: here as timezone modifications
     * only affect datetimes, not dates
     */
    recur.until = [endDate iCalTime];
    recur.freq = frequency;
  }
  return self;
}
- (id)initWithFrequency:(recurrenceFrequency)frequency count:(int)count
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  self = [self init];
  if (self) {
    recur.count = count;
    recur.freq = frequency;
  }
  return self;
}
- (NSEnumerator *)enumeratorFromDate:(Date *)start
{
  NSAssert([start isDate], @"Works on dates");
  return AUTORELEASE([[NSRecurrenceEnumerator alloc] initWithRule:self start:start]);
}
@end

@implementation RecurrenceRule(iCalendar)
- (id)initWithICalRRule:(struct icalrecurrencetype)rrule
{
  self = [super init];
  if (self)
    recur = rrule;
  return self;
}
- (id)initWithICalString:(NSString *)rrule
{
  self = [super init];
  if (self)
    recur = icalrecurrencetype_from_string([rrule cString]);
  return self;
}
- (struct icalrecurrencetype)iCalRRule
{
  return recur;
}
@end

@implementation RecurrenceRule(NSCoding)
- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:[NSString stringWithCString:icalrecurrencetype_as_string(&recur)] forKey:@"rrule"];
}
- (id)initWithCoder:(NSCoder *)coder
{
  recur = icalrecurrencetype_from_string([[coder decodeObjectForKey:@"rrule"] cString]);
  return self;
}
@end
