/* emacs buffer mode hint -*- objc -*- */

#import "MemoryStore.h"

@interface LocalStore : MemoryStore <AgendaStore>
{
  NSString *_globalPath;
  NSString *_globalFile;
  NSString *_globalTaskFile;
}
@end

