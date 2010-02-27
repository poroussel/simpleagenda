/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "iCalTree.h"
#import "WebDAVResource.h"

@interface iCalStore : MemoryStore <SharedStore, ConfigListener>
{
  iCalTree *_tree;
  NSURL *_url;
  NSTimer *_refreshTimer;
  WebDAVResource *_resource;
}
@end
