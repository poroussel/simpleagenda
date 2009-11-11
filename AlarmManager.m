#import <Foundation/Foundation.h>
#import "AlarmManager.h"
#import "StoreManager.h"
#import "MemoryStore.h"
#import "Element.h"
#import "SAAlarm.h"

@interface AlarmManager(Private)
- (void)setAlarmsForElement:(Element *)element;
- (void)setAlarmsForElements:(NSArray *)elements;
- (id)init;
@end

@implementation AlarmManager(Private)
- (void)absoluteTrigger:(SAAlarm *)alarm
{
  NSLog([alarm description]);
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

- (void)dataChanged:(NSNotification *)not
{
  MemoryStore *store = [not object];
  NSLog(@"AlarmManager dataChanged:");
  [self setAlarmsForElements:[store events]];
  [self setAlarmsForElements:[store tasks]];
}

- (id)init
{
  StoreManager *sm;

  self = [super init];
  if (self) {
    sm = [StoreManager globalManager];
    [self setAlarmsForElements:[sm allEvents]];
    [self setAlarmsForElements:[sm allTasks]];
    /*
     * FIXME : s'inscrire aux 
     * notifications de detail (ajout/suppression/modification) ?
     */
    [[NSNotificationCenter defaultCenter] addObserver:self 
					     selector:@selector(dataChanged:) 
					         name:SADataChangedInStore 
					       object:nil];
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
@end
