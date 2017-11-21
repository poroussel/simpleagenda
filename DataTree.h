/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@interface DataTree : NSObject
{
  NSMutableArray *_children;
  NSMutableDictionary *_attributes;
}

+ (id)dataTreeWithAttributes:(NSDictionary *)attributes;
- (void)setChildren:(NSArray *)children;
- (void)addChild:(id)child;
- (void)removeChildren;
- (NSArray *)children;
- (void)setAttributes:(NSDictionary *)attributes;
- (void)setValue:(id)value forKey:(NSString *)key;
- (id)valueForKey:(NSString *)key;
- (void)sortChildrenUsingFunction:(NSComparisonResult (*)(id, id, void *))compare context:(void *)context;
@end
