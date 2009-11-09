#import <Foundation/Foundation.h>
#import "AlarmManager.h"
#import "StoreManager.h"
#import "MemoryStore.h"
#import "Element.h"
#import "SAAlarm.h"

@interface AlarmManager(Private)
- (void)setAlarmsFromElements:(NSArray *)elements;
- (id)init;
@end

@implementation AlarmManager(Private)
- (void)absoluteTimer:(NSTimer *)timer
{
  SAAlarm *alarm = [timer userInfo];
  NSLog([alarm description]);
}

- (void)setAlarmsFromElements:(NSArray *)elements
{
  NSEnumerator *enumerator = [elements objectEnumerator];
  NSEnumerator *enumAlarm;
  Element *element;
  SAAlarm *alarm;
  NSTimer *timer;

  while ((element = [enumerator nextObject])) {
    if ([[element store] displayed] && [element hasAlarms]) {
      enumAlarm = [[element alarms] objectEnumerator];
      while ((alarm = [enumAlarm nextObject])) {
	if ([alarm isAbsoluteTrigger]) {
	  NSLog(@"absoluteTrigger %@", [[alarm absoluteTrigger] description]);
	  timer = [[NSTimer alloc] initWithFireDate:[[alarm absoluteTrigger] calendarDate]
				           interval:0
				             target:self
				           selector:@selector(absoluteTimer:)
              				   userInfo:alarm
				            repeats:NO];
	  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
	  [timer release];
	} else {
	  NSLog(@"relativeTrigger");
	}
      }
    }
  }
}

- (id)init
{
  StoreManager *sm;

  self = [super init];
  if (self) {
    sm = [StoreManager globalManager];
    [self setAlarmsFromElements:[sm allEvents]];
    [self setAlarmsFromElements:[sm allTasks]];
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

- (void)dataChanged:(NSNotification *)not
{
  MemoryStore *store = [not object];
  
  [self setAlarmsFromElements:[store events]];
  [self setAlarmsFromElements:[store tasks]];
}
@end
