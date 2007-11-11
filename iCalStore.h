/* emacs buffer mode hint -*- objc -*- */

#import "AgendaStore.h"
#import "ConfigManager.h"
#import "iCalTree.h"

@interface iCalStoreDialog : NSObject
{
  IBOutlet id panel;
  IBOutlet id name;
  IBOutlet id url;
  IBOutlet id ok;
  IBOutlet id error;
  IBOutlet id warning;
}

@end

@interface iCalStore : NSObject <AgendaStore>
{
  iCalTree *_tree;
  ConfigManager *_config;
  NSMutableDictionary *_data;
  NSMutableDictionary *_tasks;
  NSString *_name;
  NSURL *_url;
  NSDate *_lastModified;
  BOOL _modified;
  BOOL _writable;
  BOOL _displayed;
  int _minutesBeforeRefresh;
  NSTimer *_refreshTimer;
  id _delegate;
  NSMutableData *_retrievedData;
}

@end
