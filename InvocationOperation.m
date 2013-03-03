/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "InvocationOperation.h"

@implementation InvocationOperation
- (id)initWithInvocation:(NSInvocation *)inv
{
  if ((self = [super init]))
    _invocation = [inv retain];
  return self;
}
- (id)initWithTarget:(id)target selector:(SEL)sel object:(id)arg
{
  NSInvocation *inv;

  inv = [NSInvocation invocationWithMethodSignature:[target methodSignatureForSelector:sel]];
  [inv setTarget:target];
  [inv setSelector:sel];
  if (arg)
    [inv setArgument:&arg atIndex:2];
  return [[InvocationOperation alloc] initWithInvocation:inv];
}
- (void)dealloc
{
  [_invocation release];
  [super dealloc];
}
- (void)main
{
  NSDebugLLog(@"SimpleAgenda", @"%@", [_invocation description]);
  [_invocation invoke];
}
@end
