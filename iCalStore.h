/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "ConfigManager.h"

@interface iCalStore : NSObject <AgendaStore>
{
  ConfigManager *_config;
  NSMutableSet *_set;
  NSString *_name;
  NSURL *_url;
  NSDate *_lastModified;
  BOOL _modified;
  BOOL _writable;
  BOOL _displayed;
  int _minutesBeforeRefresh;
  icalcomponent *_icomp;
  NSTimer *_refreshTimer;
  id _delegate;
}

@end
