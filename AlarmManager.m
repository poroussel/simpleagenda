#import <Foundation/Foundation.h>
#import "AlarmManager.h"
#import "StoreManager.h"
#import "MemoryStore.h"
#import "Element.h"
#import "SAAlarm.h"

@implementation AlarmManager(Private)
- (void)absoluteTrigger:(SAAlarm *)alarm
{
  NSLog([alarm description]);
}

- (void)addAlarm:(SAAlarm *)alarm forUID:(NSString *)uid
{
  NSMutableArray *alarms = [_activeAlarms objectForKey:uid];

  if (!alarms) {
    alarms = [NSMutableArray arrayWithCapacity:2];
    [_activeAlarms setObject:alarms forKey:uid];
  }
  [alarms addObject:alarm];
}

- (void)removeAlarmsforUID:(NSString *)uid
{
  NSMutableArray *alarms = [_activeAlarms objectForKey:uid];
  NSEnumerator *enumerator;
  SAAlarm *alarm;
  
  if (alarms) {
    enumerator = [alarms objectEnumerator];
    while ((alarm = [enumerator nextObject])) {
      [NSObject cancelPreviousPerformRequestsWithTarget:self 
	                                       selector:@selector(absoluteTrigger:) 
	                                         object:alarm]; 
    }
    [_activeAlarms removeObjectForKey:uid];
  }
}

- (void)setAlarmsForElement:(Element *)element
{
  NSEnumerator *enumAlarm;
  SAAlarm *alarm;
  NSDate *date;

  if (![[element store] displayed] || ![element hasAlarms])
    return;
  enumAlarm = [[element alarms] objectEnumerator];
  while ((alarm = [enumAlarm nextObject])) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self 
	                                     selector:@selector(absoluteTrigger:) 
	                                       object:alarm]; 
    if ([alarm isAbsoluteTrigger]) {
      date = [[alarm absoluteTrigger] calendarDate];
      if ([date timeIntervalSinceNow] < 0)
	break;
      [self addAlarm:alarm forUID:[element UID]];
      [self performSelector:@selector(absoluteTrigger:) 
   	         withObject:alarm 
	         afterDelay:[date timeIntervalSinceNow]];
      NSLog(@"absoluteTrigger %@", [date description]);
    } else {
      NSLog(@"relativeTrigger");
    }
  }
}

- (void)setAlarmsForElements:(NSArray *)elements
{
  NSEnumerator *enumerator = [elements objectEnumerator];
  Element *element;

  while ((element = [enumerator nextObject]))
    [self setAlarmsForElement:element];
}

- (void)elementAdded:(NSNotification *)not
{
  MemoryStore *store = [not object];
  NSString *uid = [[not userInfo] objectForKey:@"UID"];

  NSLog(@"Add alarms for %@", uid);
  [self setAlarmsForElement:[store elementWithUID:uid]];
}

- (void)elementRemoved:(NSNotification *)not
{
  NSString *uid = [[not userInfo] objectForKey:@"UID"];

  NSLog(@"Remove alarms for %@", uid);
  [self removeAlarmsforUID:uid];
}

- (void)elementUpdated:(NSNotification *)not
{
  //MemoryStore *store = [not object];
  NSString *uid = [[not userInfo] objectForKey:@"UID"];

  NSLog(@"Update alarms for %@", uid);
}

- (id)init
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  StoreManager *sm;

  self = [super init];
  if (self) {
    _activeAlarms = [[NSMutableDictionary alloc] initWithCapacity:32];
    sm = [StoreManager globalManager];
    [nc addObserver:self 
	   selector:@selector(elementAdded:) 
	       name:SAElementAddedToStore
	     object:nil];
    [nc addObserver:self 
	   selector:@selector(elementRemoved:) 
	       name:SAElementRemovedFromStore
	     object:nil];
    [nc addObserver:self 
	   selector:@selector(elementUpdated:) 
	       name:SAElementUpdatedInStore
	     object:nil];
    [self setAlarmsForElements:[sm allEvents]];
    [self setAlarmsForElements:[sm allTasks]];
  }
  return self;
}
@end

@implementation AlarmManager
+ (AlarmManager *)globalManager
{
  static AlarmManager *singleton;

  if (singleton == nil)
    singleton = [[AlarmManager alloc] init];
  return singleton;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  RELEASE(_activeAlarms);
  [super dealloc];
}
@end
