/* emacs buffer mode hint -*- objc -*- */

#import "HourFormatter.h"

@implementation HourFormatter

- (NSString *)stringForObjectValue:(id)anObject
{
  if (![anObject isKindOfClass:[NSNumber class]])
    return nil;
  int m = ([anObject floatValue] - [anObject intValue]) * 100;
  return [NSString stringWithFormat:@"%dh%2d", [anObject intValue], 60 * m / 100];
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
  return NO;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes
{
  return nil;
}

@end
