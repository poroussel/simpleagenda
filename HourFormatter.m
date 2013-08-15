/* emacs buffer mode hint -*- objc -*- */

#import "HourFormatter.h"

@implementation HourFormatter
+ (NSString *)stringForObjectValue:(id)anObject
{
  int hours;
  int minutes;

  if (![anObject isKindOfClass:[NSNumber class]])
    return nil;
  hours = [anObject intValue] / 3600;
  minutes = [anObject intValue] / 60 - hours * 60;
  return [NSString stringWithFormat:@"%dh%02d", hours, minutes];
}

- (NSString *)stringForObjectValue:(id)anObject
{
  return [HourFormatter stringForObjectValue:anObject];
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
  NSNumberFormatter *nf;
  NSNumber *hours;
  NSNumber *minutes;
  NSArray *components = [string componentsSeparatedByString:@"h"];

  if (!components || [components count] != 2) {
    if (error)
      *error = [[NSString alloc] initWithString:@"Bad time formatting : cannot find hours and minutes separated by h"];
    return NO;
  }
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  hours = [nf numberFromString:[components objectAtIndex:0]];
  minutes = [nf numberFromString:[components objectAtIndex:1]];
  if (!hours || !minutes) {
    if (error)
      *error = [[NSString alloc] initWithString:@"Bad time formatting"];
    return NO;
  }
  if ([hours intValue] < 0 || [hours intValue] > 23) {
    if (error)
      *error = [[NSString alloc] initWithString:@"Hours must be between 0 and 23"];
    return NO;
  }
  if ([minutes intValue] < 0 || [minutes intValue] > 59) {
    if (error)
      *error = [[NSString alloc] initWithString:@"Minutes must be between 0 and 59"];
    return NO;
  }
  *anObject = [[NSNumber alloc] initWithInt:[hours intValue] * 3600 + [minutes intValue] * 60.0];
  return YES;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes
{
  return nil;
}
@end
