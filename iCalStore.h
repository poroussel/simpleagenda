/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"

@interface iCalStore : NSObject <AgendaStore>
{
  NSMutableDictionary *_params;
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
