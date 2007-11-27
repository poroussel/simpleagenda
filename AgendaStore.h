/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>

#define SADataChangedInStore @"DataDidChangedInStore"

@class Element;
@class Event;
@class Task;

@protocol MemoryStore <NSObject>
+ (id)storeNamed:(NSString *)name;
- (id)initWithName:(NSString *)name;
+ (BOOL)registerWithName:(NSString *)name;
+ (NSString *)storeTypeName;
- (NSArray *)events;
- (NSArray *)tasks;
- (void)add:(Element *)evt;
- (void)remove:(Element *)elt;
- (void)update:(Element *)evt;
- (BOOL)contains:(Element *)elt;
- (BOOL)modified;
- (BOOL)writable;
- (void)setWritable:(BOOL)writable;
- (NSColor *)eventColor;
- (void)setEventColor:(NSColor *)color;
- (NSColor *)textColor;
- (void)setTextColor:(NSColor *)color;
- (BOOL)displayed;
- (void)setDisplayed:(BOOL)state;
@end

@protocol StoreBackend
- (BOOL)read;
- (BOOL)write;
@end

@protocol AgendaStore <MemoryStore, StoreBackend>
@end
