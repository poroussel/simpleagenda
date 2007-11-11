/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "Element.h"
#import "ical.h"

@interface iCalTree : NSObject
{
  icalcomponent *root;
}

- (BOOL)parseString:(NSString *)string;
- (NSString *)iCalTreeAsString;
- (NSSet *)components;
- (BOOL)add:(Element *)event;
- (BOOL)remove:(Element *)event;
- (BOOL)update:(Element *)event;
@end

