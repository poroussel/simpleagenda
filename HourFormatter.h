/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@interface HourFormatter : NSFormatter

- (NSString *)stringForObjectValue:(id)anObject;
- (BOOL)getObjectValue:(id *)anObject
	     forString:(NSString *)string 
      errorDescription:(NSString **)error;
- (NSAttributedString *)attributedStringForObjectValue:(id)anObject 
				 withDefaultAttributes:(NSDictionary *)attributes;

@end
