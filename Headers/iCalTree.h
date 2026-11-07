/* emacs buffer mode hint -*- objc -*- */

#import "config.h"
#import <Foundation/Foundation.h>
#import "Element.h"

@interface iCalTree : NSObject
{
  icalcomponent *root;
}

- (BOOL)parseString:(NSString *)string;
- (BOOL)parseData:(NSData *)data;
- (NSString *)iCalTreeAsString;
- (NSData *)iCalTreeAsData;
- (NSSet *)components;
- (BOOL)add:(Element *)event;
- (BOOL)remove:(Element *)event;
- (BOOL)update:(Element *)event;
@end

