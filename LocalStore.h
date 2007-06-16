/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"

@interface LocalStore : NSObject <AgendaStore>
{
  id _manager;
  NSMutableDictionary *_params;
  NSMutableSet *_set;
  BOOL _modified;
  NSString *_globalPath;
  NSString *_globalFile;
  NSString *_name;
  BOOL _displayed;
}

@end

