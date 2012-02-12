/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "ConfigManager.h"

extern NSString * const SADataChangedInStore;
extern NSString * const SAStatusChangedForStore;
extern NSString * const SAEnabledStatusChangedForStore;
extern NSString * const SAElementAddedToStore;
extern NSString * const SAElementRemovedFromStore;
extern NSString * const SAElementUpdatedInStore;
extern NSString * const SAErrorReadingStore;
extern NSString * const SAErrorWritingStore;

@class Element;
@class NSColor;

@protocol MemoryStore <NSObject>
+ (BOOL)registerWithName:(NSString *)name;
+ (id)storeNamed:(NSString *)name;
+ (BOOL)isUserInstanciable;
+ (NSString *)storeName;
+ (NSString *)storeTypeName;
- (id)initWithName:(NSString *)name;
- (ConfigManager *)config;
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
