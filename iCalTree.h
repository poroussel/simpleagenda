/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "Event.h"
#import "ical.h"

@interface iCalTree : NSObject
{
  icalcomponent *root;
}

- (BOOL)parseString:(NSString *)string;
- (NSString *)iCalTreeAsString;
- (NSSet *)events;
- (BOOL)add:(Event *)event;
- (BOOL)remove:(Event *)event;
- (BOOL)update:(Event *)event;
@end

