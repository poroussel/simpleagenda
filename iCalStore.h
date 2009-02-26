/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "iCalTree.h"
#import "WebDAVResource.h"

@interface iCalStore : MemoryStore <AgendaStore, PeriodicRefresh, ConfigListener>
{
  iCalTree *_tree;
  NSURL *_url;
  NSTimer *_refreshTimer;
  WebDAVResource *_resource;
}
@end
