/* emacs objective-c mode -*- objc -*- */

@interface AppointmentCache : NSObject
{
  StoreManager *_sm;
  Date *_start;
  Date *_end;
  NSMutableSet *_cache;
  NSString *_title;
  id _delegate;
}

- (id)initwithStoreManager:(StoreManager *)sm  
		      from:(Date *)start 
			to:(Date *)end;
- (void)setFrom:(Date *)start to:(Date *)end;
- (void)setTitle:(NSString *)title;
- (NSString *)title;
- (NSString *)details;
- (NSEnumerator *)enumerator;
- (NSArray *)array;
- (unsigned int)count;
- (void)setDelegate:(id)delegate;
- (id)delegate;

@end

@interface NSObject(AppointmentCacheDelegate)
- (void)dataChangedInCache:(AppointmentCache *)ac;
@end
