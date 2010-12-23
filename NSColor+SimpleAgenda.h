/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/NSColor.h>

/* 
 * This method is available but not defined. Avoid
 * a compilation warning by declaring it here.
 */
@interface NSColor(NotDefinedMethods)
+ (NSColor *)colorFromString:(NSString *)string;
@end

@interface NSColor(SimpleAgenda)
- (NSColor *)colorModifiedWithDeltaRed:(float)red green:(float)green blue:(float)blue alpha:(float)alpha;
@end
