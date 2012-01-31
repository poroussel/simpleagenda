/* emacs buffer mode hint -*- objc -*- */

#import "MemoryStore.h"

@protocol StoreBackend
- (void)read;
- (void)write;
@end

@protocol PeriodicRefresh
- (BOOL)periodicRefresh;
- (void)setPeriodicRefresh:(BOOL)periodic;
- (NSTimeInterval)refreshInterval;
- (void)setRefreshInterval:(NSTimeInterval)interval;
@end

@protocol AgendaStore <MemoryStore, StoreBackend>
@end

@protocol SharedStore <AgendaStore, PeriodicRefresh>
@end
