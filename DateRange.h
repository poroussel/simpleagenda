/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "Date.h"

@interface DateRange : NSObject
{
  Date *_start;
  NSTimeInterval _length;
}

- (id)initWithStart:(Date *)date duration:(NSTimeInterval)seconds;
- (id)initWithDay:(Date *)day;
- (void)setStart:(Date *)start;
- (void)setLength:(NSTimeInterval)seconds;
- (Date *)start;
- (NSTimeInterval)length;
- (BOOL)contains:(Date *)date;
- (BOOL)intersectsWith:(DateRange *)range;
- (BOOL)intersectsWithDay:(Date *)day;
- (NSRange)intersectionWithDay:(Date *)day;
@end
