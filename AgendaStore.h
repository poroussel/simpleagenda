/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "Event.h"

@protocol AgendaStore <NSObject>
+ (id)storeNamed:(NSString *)name forManager:(id)manager;
- (NSArray *)scheduledAppointmentsFor:(Date *)day;
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

@interface NSObject(AgendaStoreDelegate)
- (void)dataChanged:(id <AgendaStore>)agenda;
@end
