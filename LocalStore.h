/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "ConfigManager.h"

@interface LocalStore : NSObject <AgendaStore>
{
  ConfigManager *_config;
  NSMutableDictionary *_data;
  NSMutableDictionary *_tasks;
  BOOL _modified;
  NSString *_globalPath;
  NSString *_globalFile;
  NSString *_globalTaskFile;
  NSString *_name;
  BOOL _displayed;
  BOOL _writable;
}

@end

