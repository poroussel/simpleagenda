/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "ConfigManager.h"

@interface LocalStore : NSObject <AgendaStore>
{
  id _manager;
  ConfigManager *_config;
  NSMutableDictionary *_data;
  BOOL _modified;
  NSString *_globalPath;
  NSString *_globalFile;
  NSString *_name;
  BOOL _displayed;
  BOOL _writable;
}

@end

