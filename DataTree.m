#import "DataTree.h"

@implementation DataTree
- (id)init
{
  if ((self = [super init])) {
    _children = [NSMutableArray new];
    _attributes = [NSMutableDictionary new];
  }
  return self;
}

- (void)dealloc
{
  [_attributes release];
  [_children release];
  [super dealloc];
}

- (id)initWithAttributes:(NSDictionary *)attributes
{
  if ((self = [self init]))
    [self setAttributes:attributes];
  return self;
}

+ (id)dataTreeWithAttributes:(NSDictionary *)attributes
{
  return [[[DataTree alloc] initWithAttributes:attributes] autorelease];
}

- (void)setChildren:(NSArray *)children
{
  [_children setArray:children];
}

- (void)addChild:(id)child
{
  [_children addObject:child];
}

- (void)removeChildren
{
  [_children removeAllObjects];
}

- (NSArray *)children
{
  return _children;
}

- (void)setAttributes:(NSDictionary *)attributes
{
  [_attributes setDictionary:attributes];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
  [_attributes setValue:value forKey:key];
}

- (id)valueForKey:(NSString *)key
{
  return [_attributes valueForKey:key];
}

- (void)sortChildrenUsingFunction:(NSComparisonResult (*)(id, id, void *))compare context:(void *)context
{
  [_children sortUsingFunction:compare context:context];
}
@end
