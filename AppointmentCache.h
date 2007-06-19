/* emacs objective-c mode -*- objc -*- */

@interface AppointmentCache : NSObject
{
  StoreManager *_sm;
  Date *_start;
  Date *_end;
  NSMutableSet *_cache;
  NSString *_title;
}

- (id)initwithStoreManager:(StoreManager *)sm  
		      from:(Date *)start 
			to:(Date *)end;
- (void)setFrom:(Date *)start to:(Date *)end;
- (void)setTitle:(NSString *)title;
- (NSString *)title;
- (void)refresh;
- (NSEnumerator *)enumerator;
- (NSArray *)array;
- (unsigned int)count;

@end

