#import "RecurrenceRule.h"
#import "DateRange.h"

@interface DateRecurrenceEnumerator : NSEnumerator
{
  icalrecur_iterator *_iterator;
}
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start;
@end
@implementation DateRecurrenceEnumerator
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start;
{
  self = [super init];
  /*
   * It's OK to use Date iCaltime: here as timezone modifications
   * only affect datetimes, not dates
   */
  if (self)
    _iterator = icalrecur_iterator_new([rule iCalRRule],  [start iCalTime]);
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

@interface DateRangeRecurrenceEnumerator : NSEnumerator
{
  icalrecur_iterator *_iterator;
  NSTimeInterval _length;
}
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start length:(NSTimeInterval)length;
@end
@implementation DateRangeRecurrenceEnumerator
- (id)initWithRule:(RecurrenceRule *)rule start:(Date *)start length:(NSTimeInterval)length;
{
  self = [super init];
  if (self) {
    _iterator = icalrecur_iterator_new([rule iCalRRule],  [start iCalTime]);
    _length = length;
  }
  return self;
}
- (id)nextObject
{
  Date *date;
  struct icaltimetype next;
  
  next = icalrecur_iterator_next(_iterator);
  if (icaltime_is_null_time(next))
    return nil;
  date = AUTORELEASE([[Date alloc] initWithICalTime:next]);
  return AUTORELEASE([[DateRange alloc] initWithStart:date duration:_length]);
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
  self = [self init];
  if (self)
    recur.freq = frequency;
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
/* FIXME : this one expect a day */
- (NSEnumerator *)enumeratorFromDate:(Date *)start
{
  NSAssert([start isDate], @"Works on dates");
  return AUTORELEASE([[DateRecurrenceEnumerator alloc] initWithRule:self start:start]);
}
/*
 * FIXME : and this one a datetime
 * We have to now if using datetimes will generate timezone problems
 * See DateRecurrenceEnumerator
 */
- (NSEnumerator *)enumeratorFromDate:(Date *)start length:(NSTimeInterval)length
{
  return AUTORELEASE([[DateRangeRecurrenceEnumerator alloc] initWithRule:self start:start length:length]);
}
- (recurrenceFrequency)frequency
{
  return recur.freq;
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
