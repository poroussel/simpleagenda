#import <Foundation/Foundation.h>
#import "AlarmManager.h"
#import "StoreManager.h"
#import "ConfigManager.h"
#import "MemoryStore.h"
#import "Element.h"
#import "SAAlarm.h"
#import "AlarmBackend.h"

NSString * const ACTIVATE_ALARMS = @"activateAlarms";
NSString * const DEFAULT_ALARM_BACKEND = @"defaultAlarmBackend";

static NSMutableDictionary *backendsArray;
static AlarmManager *singleton;

@interface AlarmManager(Private)
+ (void)addBackendClass:(Class)class;
- (void)removeAlarms;
- (void)createAlarms;
@end

@implementation AlarmManager(Private)
+ (void)addBackendClass:(Class)class
{
  id backend;

  backend = [class new];
  if (backend) {
    [backendsArray setObject:backend forKey:[class backendName]];
    [backend release];
    NSLog(@"Alarm backend <%@> registered", [class backendName]);
  }
}

- (void)runAlarm:(SAAlarm *)alarm
{
  if (_defaultBackend)
    [_defaultBackend display:alarm];
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
    while ((alarm = [enumerator nextObject]))
      [NSObject cancelPreviousPerformRequestsWithTarget:self 
	                                       selector:@selector(runAlarm:) 
	                                         object:alarm]; 
    [_activeAlarms removeObjectForKey:uid];
  }
}

- (BOOL)addAbsoluteAlarm:(SAAlarm *)alarm
{
  NSDate *date = [[alarm absoluteTrigger] calendarDate];

  if ([date timeIntervalSinceNow] < 0)
    return NO;
  [self performSelector:@selector(runAlarm:) 
	     withObject:alarm 
	     afterDelay:[date timeIntervalSinceNow]];
  return YES;
}

/* FIXME */
- (BOOL)addRelativeAlarm:(SAAlarm *)alarm
{
  return NO;
}

- (void)setAlarmsForElement:(Element *)element
{
  NSEnumerator *enumAlarm;
  SAAlarm *alarm;
  BOOL added;

  if (![[element store] displayed] || ![element hasAlarms])
    return;
  enumAlarm = [[element alarms] objectEnumerator];
  while ((alarm = [enumAlarm nextObject])) {
    if ([alarm isAbsoluteTrigger])
      added = [self addAbsoluteAlarm:alarm];
    else
      added = [self addRelativeAlarm:alarm];
    if (added)
      [self addAlarm:alarm forUID:[element UID]];
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
  [self createAlarms];
}

- (void)elementAdded:(NSNotification *)not
{
  if (_active) {
    MemoryStore *store = [not object];
    NSString *uid = [[not userInfo] objectForKey:@"UID"];
    
    [self setAlarmsForElement:[store elementWithUID:uid]];
  }
}

- (void)elementRemoved:(NSNotification *)not
{
  if (_active)
    [self removeAlarmsforUID:[[not userInfo] objectForKey:@"UID"]];
}

- (void)elementUpdated:(NSNotification *)not
{
  if (_active) {
    MemoryStore *store = [not object];
    NSString *uid = [[not userInfo] objectForKey:@"UID"];

    [self removeAlarmsforUID:uid];
    [self setAlarmsForElement:[store elementWithUID:uid]];
  }
}

- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithBool:YES], [AlarmBackend backendName], nil] 
				     forKeys:[NSArray arrayWithObjects: ACTIVATE_ALARMS, DEFAULT_ALARM_BACKEND, nil]];
}

/* FIXME : what happens when a store is reloaded ? */
- (id)init
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  ConfigManager *cm = [ConfigManager globalConfig];

  self = [super init];
  if (self) {
    [cm registerDefaults:[self defaults]];
    _active = [[cm objectForKey:ACTIVATE_ALARMS] boolValue];
    [self setDefaultBackend:[cm objectForKey:DEFAULT_ALARM_BACKEND]];

    _activeAlarms = [[NSMutableDictionary alloc] initWithCapacity:32];
    [nc addObserver:self 
	   selector:@selector(dataChanged:) 
	       name:SADataChangedInStore
	     object:nil];
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

    [self createAlarms];
    NSLog(@"Alarms are %@", _active ? @"enabled" : @"disabled");
    [cm registerClient:self forKey:ACTIVATE_ALARMS];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[ConfigManager globalConfig] unregisterClient:self];
  RELEASE(_activeAlarms);
  [super dealloc];
}

- (void)createAlarms
{
  StoreManager *sm = [StoreManager globalManager];

  [self removeAlarms];
  if (_active) {
    [self setAlarmsForElements:[sm allEvents]];
    [self setAlarmsForElements:[sm allTasks]];
  }
}

- (void)removeAlarms
{
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  [_activeAlarms removeAllObjects];
}
@end

@implementation AlarmManager
+ (void)initialize
{
  NSArray *classes;
  NSEnumerator *enumerator;
  Class backendClass;

  if ([AlarmManager class] == self) {
    classes = GSObjCAllSubclassesOfClass([AlarmBackend class]);
    backendsArray = [[NSMutableDictionary alloc] initWithCapacity:[classes count]+1];
    enumerator = [classes objectEnumerator];
    while ((backendClass = [enumerator nextObject]))
      [self addBackendClass:backendClass];
    [self addBackendClass:[AlarmBackend class]];
    singleton = [[AlarmManager alloc] init];
  }
}

+ (NSArray *)backends
{
  return [backendsArray allValues];
}

+ (id)backendForName:(NSString *)name
{
  return [backendsArray objectForKey:name];
}

+ (AlarmManager *)globalManager
{
  return singleton;
}

- (id)defaultBackend
{
  return _defaultBackend;
}

- (void)setDefaultBackend:(NSString *)name
{
  id bck = [AlarmManager backendForName:name];
  if (bck != nil) {
    _defaultBackend = bck;
    NSLog(@"Default alarm backend is <%@>", name);
  }
}

- (void)config:(ConfigManager *)config dataDidChangedForKey:(NSString *)key
{
  _active = [[config objectForKey:ACTIVATE_ALARMS] boolValue];
  if (_active)
    [self createAlarms];
  else
    [self removeAlarms];
}
@end


@implementation AlarmBackend
+ (NSString *)backendName
{
  return @"Log backend";
}
- (NSString *)backendType
{
  return SAActionDisplay;
}
- (void)display:(SAAlarm *)alarm
{
  NSLog([alarm description]);
}
@end
