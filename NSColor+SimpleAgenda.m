#import "NSColor+SimpleAgenda.h"

@implementation NSColor(SimpleAgenda)
- (NSColor *)colorModifiedWithDeltaRed:(float)red green:(float)green blue:(float)blue alpha:(float)alpha;
{
  return [NSColor colorWithCalibratedRed:[self redComponent] + red
                                   green:[self greenComponent] + green
		                    blue:[self blueComponent] + blue
		                   alpha:[self alphaComponent] + alpha];
}
@end
