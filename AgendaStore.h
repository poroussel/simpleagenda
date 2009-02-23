/* emacs buffer mode hint -*- objc -*- */

#import "MemoryStore.h"

@protocol StoreBackend
- (BOOL)read;
- (BOOL)write;
@end

@protocol AgendaStore <MemoryStore, StoreBackend>
@end
