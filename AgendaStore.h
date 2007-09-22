/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>

#define SADataChangedInStore @"DataDidChangedInStore"

@class Event;

@protocol AgendaStore <NSObject>
+ (id)storeNamed:(NSString *)name;
+ (BOOL)registerWithName:(NSString *)name;
+ (NSString *)storeTypeName;
- (NSEnumerator *)enumerator;
- (NSArray *)events;
- (void)add:(Event *)evt;
- (void)remove:(NSString *)uid;
- (void)update:(NSString *)uid with:(Event *)evt;
- (BOOL)contains:(NSString *)uid;
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
