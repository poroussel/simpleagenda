#import "DataTree.h"

@implementation DataTree
- (id)init
{
  self = [super init];
  if (self) {
    _parent = nil;
    _children = [[NSMutableArray alloc] init];
    _attributes = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_parent);
  [_attributes release];
  [_children release];
  [super dealloc];
}

- (id)initWithAttributes:(NSDictionary *)attributes
{
  self = [self init];
  if (self)
    [self setAttributes:attributes];
  return self;
}

+ (id)dataTreeWithAttributes:(NSDictionary *)attributes
{
  return AUTORELEASE([[DataTree alloc] initWithAttributes:attributes]);
}

- (void)setParent:(id)parent
{
  ASSIGN(_parent, parent);
}

- (id)parent
{
  return _parent;
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
@end
