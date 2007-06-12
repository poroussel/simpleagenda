/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"

@interface iCalStore : NSObject <AgendaStore>
{
  NSMutableDictionary *_params;
  NSMutableSet *_set;
  NSString *_name;
  NSURL *_url;
  BOOL _modified;
  BOOL _writable;
  int _minutesBeforeRefresh;
  icalcomponent *_icomp;
}

@end
