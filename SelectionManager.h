/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

typedef enum {
  SMCopy,
  SMCut
} SMOperation;

@interface SelectionManager : NSObject
{
  NSMutableArray *_objects;
  NSMutableArray *_copyarea;
  SMOperation _operation;
}

+ (SelectionManager *)globalManager;
- (int)count;
- (int)copiedCount;
- (void)select:(id)object;
- (void)clear;
- (id)lastObject;
- (void)copySelection;
- (void)cutSelection;
- (NSArray *)paste;
- (NSArray *)selection;
- (NSEnumerator *)enumerator;
- (SMOperation)lastOperation;
@end
