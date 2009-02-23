/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "WebDAVResource.h"

@interface GroupDAVStore : MemoryStore <AgendaStore>
{
  NSURL *_url;
  WebDAVResource *_calendar;
  WebDAVResource *_task;
  NSMutableDictionary *_uidhref;
  NSMutableDictionary *_hreftree;
  NSMutableDictionary *_hrefresource;
  NSMutableArray *_modifiedhref;
}
@end
