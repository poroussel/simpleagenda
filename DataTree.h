/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@interface DataTree : NSObject
{
  id _parent;
  NSMutableArray *_children;
  NSMutableDictionary *_attributes;
}

+ (id)dataTreeWithAttributes:(NSDictionary *)attributes;
- (void)setParent:(id)parent;
- (id)parent;
- (void)setChildren:(NSArray *)children;
- (void)addChild:(id)child;
- (void)removeChildren;
- (NSArray *)children;
- (void)setAttributes:(NSDictionary *)attributes;
- (void)setValue:(id)value forKey:(NSString *)key;
- (id)valueForKey:(NSString *)key;
@end
