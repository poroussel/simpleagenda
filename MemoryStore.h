/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "ConfigManager.h"

extern NSString * const SADataChangedInStore;
extern NSString * const SAStatusChangedForStore;
extern NSString * const SAEnabledStatusChangedForStore;
extern NSString * const SAElementAddedToStore;
extern NSString * const SAElementRemovedFromStore;
extern NSString * const SAElementUpdatedInStore;

@class Element;
@class NSColor;

@protocol MemoryStore <NSObject>
+ (id)storeNamed:(NSString *)name;
- (id)initWithName:(NSString *)name;
+ (BOOL)registerWithName:(NSString *)name;
+ (NSString *)storeTypeName;
- (NSArray *)events;
- (NSArray *)tasks;
- (Element *)elementWithUID:(NSString *)uid;
- (void)fillWithElements:(NSSet *)set;
- (void)add:(Element *)evt;
- (void)remove:(Element *)elt;
- (void)update:(Element *)evt;
- (BOOL)contains:(Element *)elt;
- (BOOL)modified;
- (void)setModified:(BOOL)modified;
- (BOOL)writable;
- (void)setWritable:(BOOL)writable;
- (NSColor *)eventColor;
- (void)setEventColor:(NSColor *)color;
- (NSColor *)textColor;
- (void)setTextColor:(NSColor *)color;
- (BOOL)displayed;
- (void)setDisplayed:(BOOL)state;
- (BOOL)enabled;
- (void)setEnabled:(BOOL)state;
@end

@interface MemoryStore : NSObject <MemoryStore>
{
  ConfigManager *_config;
  NSMutableDictionary *_data;
  NSMutableDictionary *_tasks;
  BOOL _modified;
  NSString *_name;
  BOOL _displayed;
  BOOL _writable;
  BOOL _enabled;
}
@end
