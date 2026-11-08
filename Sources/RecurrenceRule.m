#import "RecurrenceRule.h"

@interface DateRecurrenceEnumerator : NSEnumerator
{
  icalrecur_iterator *_iterator;
}
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start;
@end
@implementation DateRecurrenceEnumerator
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start;
{
  if ((self = [super init]))
    _iterator = icalrecur_iterator_new([rule iCalRRule],  [start localICalTime]);
  return self;
}
- (id)nextObject
{
  struct icaltimetype next;

  next = icalrecur_iterator_next(_iterator);
  if (icaltime_is_null_time(next))
    return nil;
  return AUTORELEASE([[Date alloc] initWithICalTime:next]);
}
- (void)dealloc
{
  icalrecur_iterator_free(_iterator);
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
- (id)initWithFrequency:(recurrenceFrequency)frequency
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  if ((self = [self init]))
    recur.freq = (icalrecurrencetype_frequency)frequency;
  return self;
}
- (id)initWithFrequency:(recurrenceFrequency)frequency until:(Date *)endDate
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  NSAssert([endDate isDate], @"Works on dates");
  if ((self = [self init])) {
    /*
     * It's OK to use Date iCaltime: here as timezone modifications
     * only affect datetimes, not dates
     */
    recur.until = [endDate UTCICalTime];
    recur.freq = (icalrecurrencetype_frequency)frequency;
  }
  return self;
}
- (id)initWithFrequency:(recurrenceFrequency)frequency count:(int)count
{
  NSAssert(frequency < recurrenceFrequenceOther, @"Wrong frequency");
  if ((self = [self init])) {
    recur.count = count;
    recur.freq = (icalrecurrencetype_frequency)frequency;
  }
  return self;
}
/* start is a date or a datetime, and so are the occurrences */
- (NSEnumerator *)enumeratorFromDate:(Date *)start
{
  return AUTORELEASE([[DateRecurrenceEnumerator alloc] initWithRule:self start:start]);
}
- (recurrenceFrequency)frequency
{
  return (recurrenceFrequency)recur.freq;
}
- (Date *)until
{
  if (icaltime_is_null_time(recur.until))
    return nil;
  return AUTORELEASE([[Date alloc] initWithICalTime:recur.until]);
}
- (int)count
{
  return recur.count;
}
@end

@implementation RecurrenceRule(iCalendar)
- (id)initWithICalRRule:(struct icalrecurrencetype)rrule
{
  if ((self = [super init]))
    recur = rrule;
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
