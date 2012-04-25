#import <Foundation/Foundation.h>
#import "DateRange.h"

@implementation DateRange
- (id)initWithStart:(Date *)date duration:(NSTimeInterval)seconds
{
  self = [super init];
  if (self) {
    _length = seconds;
    _start = [date retain];
  }
  return self;
}

- (id)initWithDay:(Date *)day
{
  NSAssert([day isDate], @"This method expects a date, not a datetime");
  return [self initWithStart:day duration:86400];
}

- (void)dealloc
{
  [_start release];
  [super dealloc];
}

- (Date *)start
{
  return _start;
}

- (void)setStart:(Date *)start
{
  ASSIGN(_start, start);
}

- (NSTimeInterval)length
{
  return _length;
}

- (void)setLength:(NSTimeInterval)length
{
  _length = length;
}

- (BOOL)contains:(Date *)date
{
  if ([_start compare:date withTime:YES] > 0)
    return NO;
  if ([date timeIntervalSinceDate:_start] > _length)
    return NO;
  return YES;
}

- (BOOL)intersectsWith:(DateRange *)range
{
  NSTimeInterval s1 = [_start timeIntervalSince1970];
  NSTimeInterval e1 = s1 + _length;
  NSTimeInterval s2 = [[range start] timeIntervalSince1970];
  NSTimeInterval e2 = s2 + [range length];
  NSTimeInterval s = MAX(s1, s2);
  NSTimeInterval e = MIN(e1, e2);
  if (e <= s)
    return NO;
  return YES;
}

- (BOOL)intersectsWithDay:(Date *)day
{
  NSAssert([day isDate], @"This method expects a date, not a datetime");
  NSTimeInterval s1 = [_start timeIntervalSince1970];
  NSTimeInterval e1 = s1 + _length;
  NSTimeInterval s2 = [day timeIntervalSince1970];
  NSTimeInterval e2 = s2 + 86400;
  NSTimeInterval s = MAX(s1, s2);
  NSTimeInterval e = MIN(e1, e2);
  if (e <= s)
    return NO;
  return YES;
}

- (NSRange)intersectionWithDay:(Date *)day
{
  NSAssert([day isDate], @"This method expects a date, not a datetime");
  NSTimeInterval s1 = [_start timeIntervalSince1970];
  NSTimeInterval e1 = s1 + _length;
  NSTimeInterval s2 = [day timeIntervalSince1970];
  NSTimeInterval e2 = s2 + 86400;
  NSTimeInterval s = MAX(s1, s2);
  NSTimeInterval e = MIN(e1, e2);
  if (e <= s)
    return NSMakeRange(0, 0);
  return NSMakeRange(s - s2, e - s);
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"DateRange starting %@ for %d seconds", [_start description], (int)_length];
}
@end
