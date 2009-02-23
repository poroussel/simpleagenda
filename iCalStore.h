/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "iCalTree.h"
#import "WebDAVResource.h"

@interface iCalStore : MemoryStore <AgendaStore>
{
  iCalTree *_tree;
  NSURL *_url;
  int _minutesBeforeRefresh;
  NSTimer *_refreshTimer;
  WebDAVResource *_resource;
}
@end
