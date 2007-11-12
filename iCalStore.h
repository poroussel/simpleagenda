/* emacs buffer mode hint -*- objc -*- */

#import "MemoryStore.h"
#import "iCalTree.h"

@interface iCalStore : MemoryStore <AgendaStore>
{
  iCalTree *_tree;
  NSURL *_url;
  NSDate *_lastModified;
  int _minutesBeforeRefresh;
  NSTimer *_refreshTimer;
  NSMutableData *_retrievedData;
}
@end
