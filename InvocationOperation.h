/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/NSObject.h>
#import <Foundation/NSOperation.h>

@interface InvocationOperation : NSOperation
{
  NSInvocation *_invocation;
}
- (id)initWithInvocation:(NSInvocation *)inv;
- (id)initWithTarget:(id)target selector:(SEL)sel object:(id)arg;
@end
