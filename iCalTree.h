/* emacs buffer mode hint -*- objc -*- */

#import "config.h"
#import <Foundation/Foundation.h>
#ifdef HAVE_LIBICAL_ICAL_H
#import <libical/ical.h>
#else
#import <ical.h>
#endif
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

