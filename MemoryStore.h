/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "ConfigManager.h"

@interface MemoryStore : NSObject <MemoryStore>
{
  ConfigManager *_config;
  NSMutableDictionary *_data;
  NSMutableDictionary *_tasks;
  BOOL _modified;
  NSString *_name;
  BOOL _displayed;
  BOOL _writable;
}
@end

