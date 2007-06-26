/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "Event.h"

#define SADataChangedInStore @"DataDidChangedInStore"

@protocol AgendaStore <NSObject>
+ (id)storeNamed:(NSString *)name forManager:(id)manager;
- (NSEnumerator *)enumerator;
- (void)addAppointment:(Event *)evt;
- (void)delAppointment:(Event *)evt;
- (void)updateAppointment:(Event *)evt;
- (BOOL)contains:(Event *)evt;
- (BOOL)isWritable;
- (BOOL)modified;
- (void)write;
- (NSString *)description;
- (NSColor *)eventColor;
- (void)setEventColor:(NSColor *)color;
- (BOOL)displayed;
- (void)setDisplayed:(BOOL)state;
@end
