/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "Event.h"

@protocol AgendaStore <NSObject>
+ (id)storeWithParameters:(NSDictionary *)params forManager:(id)manager;
- (NSArray *)scheduledAppointmentsFrom:(Date *)start to:(Date *)end;
- (void)addAppointment:(Event *)evt;
- (void)delAppointment:(Event *)evt;
- (void)updateAppointment:(Event *)evt;
- (BOOL)isWritable;
- (BOOL)modified;
- (void)write;
- (NSString *)description;
- (NSColor *)color;
- (void)setColor:(NSColor *)color;
@end

@interface NSObject (AgendaStoreDelegate)
- (void)dataChanged:(id <AgendaStore>)agenda;
@end
