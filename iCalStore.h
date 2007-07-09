/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "ConfigManager.h"
#import "iCalTree.h"

@interface iCalStore : NSObject <AgendaStore>
{
  iCalTree *_tree;
  ConfigManager *_config;
  NSMutableSet *_set;
  NSString *_name;
  NSURL *_url;
  NSDate *_lastModified;
  BOOL _modified;
  BOOL _writable;
  BOOL _displayed;
  int _minutesBeforeRefresh;
  NSTimer *_refreshTimer;
  id _delegate;
}

@end
