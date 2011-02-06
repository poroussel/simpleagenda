#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "SelectionManager.h"

static SelectionManager *singleton;

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
+ (void)initialize
{
  if ([SelectionManager class] == self)
    singleton = [[SelectionManager alloc] init];
}

+ (SelectionManager *)globalManager
{
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

- (void)select:(id)object
{
  if (!([[NSApp currentEvent] modifierFlags] & NSControlKeyMask))
    [_objects removeAllObjects];
  if (![_objects containsObject:object])
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
