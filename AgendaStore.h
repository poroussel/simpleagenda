/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>

#define SADataChangedInStore @"DataDidChangedInStore"

@class Element;
@class Event;
@class Task;

@protocol AgendaStore <NSObject>
+ (id)storeNamed:(NSString *)name;
+ (BOOL)registerWithName:(NSString *)name;
+ (NSString *)storeTypeName;
- (NSEnumerator *)enumerator;
- (NSArray *)events;
- (NSArray *)tasks;
- (void)addEvent:(Event *)evt;
- (void)addTask:(Task *)task;
- (void)remove:(Element *)elt;
- (void)update:(Element *)evt;
- (BOOL)contains:(Element *)elt;
- (BOOL)modified;
- (BOOL)read;
- (BOOL)write;
- (BOOL)isWritable;
- (void)setIsWritable:(BOOL)writable;
- (NSColor *)eventColor;
- (void)setEventColor:(NSColor *)color;
- (NSColor *)textColor;
- (void)setTextColor:(NSColor *)color;
- (BOOL)displayed;
- (void)setDisplayed:(BOOL)state;
@end
