/* emacs objective-c mode -*- objc -*- */

@interface AppointmentCache : NSObject
{
  StoreManager *_sm;
  Date *_start;
  Date *_end;
  int _duration;
  NSMutableSet *_cache;
  NSString *_title;
  id _delegate;
}

- (id)initwithStoreManager:(StoreManager *)sm  
		      date:(Date *)date 
		  duration:(int)days;
- (void)setDate:(Date *)date;
- (void)setDuration:(int)duration;
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
