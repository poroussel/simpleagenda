#import <Foundation/Foundation.h>
#import "SelectionManager.h"


@implementation SelectionManager(Private)
- (SelectionManager *)init
{
  self = [super init];
  if (self) {
    _objects = [NSMutableArray new];
    _copyarea = [NSMutableArray new];
  }
  return self;
}
@end



@implementation SelectionManager

static SelectionManager *singleton;

+ (SelectionManager *)globalManager
{
  if (singleton == nil)
    singleton = [[SelectionManager alloc] init];
  return singleton;
}

- (void)dealloc
{
  [_objects release];
  [_copyarea release];
  [super dealloc];
}

- (int)count
{
  return [_objects count];
}

- (int)copiedCount
{
  return [_copyarea count];
}

- (void)add:(id)object
{
  [_objects addObject:object];
}

- (void)set:(id)object
{
  [self clear];
  [_objects addObject:object];
}

- (id)pop
{
  id last = [_objects lastObject];
  [_objects removeLastObject];
  return last;
}

- (void)clear
{
  [_objects removeAllObjects];
}

- (id)lastObject
{
  return [_objects lastObject];
}

- (void)copySelection
{
  [_copyarea setArray:_objects];
  _operation = SMCopy;
}

- (void)cutSelection
{
  [_copyarea setArray:_objects];
  _operation = SMCut;
}

- (NSArray *)paste
{
  NSArray *ret = [NSArray arrayWithArray:_copyarea];
  [_copyarea removeAllObjects];
  return ret;
}

- (NSEnumerator *)enumerator
{
  return [_objects objectEnumerator];
}

- (SMOperation)lastOperation
{
  return _operation;
}
@end
