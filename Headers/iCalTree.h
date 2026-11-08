/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "Element.h"
#import "ICalComponent.h"

@interface iCalTree : NSObject
{
  ICalComponent *_root;
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

