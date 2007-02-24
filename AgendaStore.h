/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import <ChronographerSource/Date.h>
#import <ChronographerSource/Appointment.h>

@protocol AgendaStore <NSObject>
+ (id)storeWithParameters:(NSDictionary *)params forManager:(id)manager;
- (NSArray *)scheduledAppointmentsFrom:(Date *)start to:(Date *)end;
- (void)addAppointment:(Appointment *)app;
- (void)delAppointment:(Appointment *)date;
- (void)updateAppointment:(Appointment *)app;
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
