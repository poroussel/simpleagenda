/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"

@interface LocalStore : NSObject <AgendaStore>
{
  id _manager;
  NSMutableSet *_set;
  BOOL _modified;
  NSString *_filename;
  NSString *_globalPath;
  NSString *_globalFile;
  NSColor *_color;
  NSString *_name;
}

@end

