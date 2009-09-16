#import <Foundation/Foundation.h>
#import "SelectionManager.h"

@implementation SelectionManager(Private)
- (id)init
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
+ (SelectionManager *)globalManager
{
  static SelectionManager *singleton;

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
  [_objects removeAllObjects];
  [_objects addObject:object];
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
  if (_operation == SMCut)
    [_copyarea removeAllObjects];
  return ret;
}

- (NSArray *)selection
{
  return _objects;
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
