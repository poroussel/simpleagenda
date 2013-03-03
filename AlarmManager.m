#import <Foundation/Foundation.h>
#import "AlarmManager.h"
#import "StoreManager.h"
#import "ConfigManager.h"
#import "MemoryStore.h"
#import "Element.h"
#import "Alarm.h"
#import "AlarmBackend.h"

NSString * const ACTIVATE_ALARMS = @"activateAlarms";
NSString * const DEFAULT_ALARM_BACKEND = @"defaultAlarmBackend";

NSString * const SAEventReminderWillRun = @"SAEventReminderWillRun";

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
    NSLog(@"Alarm backend %@ registered", [class backendName]);
  }
}

- (void)runAlarm:(Alarm *)alarm
{
  [[NSNotificationCenter defaultCenter] postNotificationName:SAEventReminderWillRun object:alarm];
  if (_defaultBackend)
    [_defaultBackend display:alarm];
}

- (void)addAlarm:(Alarm *)alarm forUID:(NSString *)uid
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
  Alarm *alarm;

  if (alarms) {
    enumerator = [alarms objectEnumerator];
    while ((alarm = [enumerator nextObject]))
      [NSObject cancelPreviousPerformRequestsWithTarget:self
	                                       selector:@selector(runAlarm:)
	                                         object:alarm];
    [_activeAlarms removeObjectForKey:uid];
  }
}

- (BOOL)addAbsoluteAlarm:(Alarm *)alarm
{
  NSTimeInterval delay;

  delay = [[alarm absoluteTrigger] timeIntervalSinceNow];
  if (delay < 0)
    return NO;
  [self performSelector:@selector(runAlarm:)
	     withObject:alarm
	     afterDelay:delay];
  return YES;
}

- (BOOL)addRelativeAlarm:(Alarm *)alarm
{
  Date *activation = [[alarm element] nextActivationDate];
  NSTimeInterval delay;

  if (!activation)
    return NO;
  if ([[Date now] compare:activation withTime:YES] == NSOrderedDescending)
    return NO;
  activation = [Date dateWithTimeInterval:[alarm relativeTrigger] sinceDate:activation];
  delay = [activation timeIntervalSinceNow];
  if (delay < 1 && delay > -600)
    delay = 1;
  if (delay < 0)
    return NO;
  [self performSelector:@selector(runAlarm:)
	     withObject:alarm
	     afterDelay:delay];
  return YES;
}

- (void)setAlarmsForElement:(Element *)element
{
  NSEnumerator *enumAlarm;
  Alarm *alarm;
  BOOL added;

  if (![[element store] displayed] || ![element hasAlarms])
    return;
  enumAlarm = [[element alarms] objectEnumerator];
  while ((alarm = [enumAlarm nextObject])) {
    NSAssert([alarm element] != nil, @"Alarm is not linked with an element");
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
  if ([self alarmsEnabled]) {
    MemoryStore *store = [not object];
    NSString *uid = [[not userInfo] objectForKey:@"UID"];

    [self setAlarmsForElement:[store elementWithUID:uid]];
  }
}

- (void)elementRemoved:(NSNotification *)not
{
  if ([self alarmsEnabled])
    [self removeAlarmsforUID:[[not userInfo] objectForKey:@"UID"]];
}

- (void)elementUpdated:(NSNotification *)not
{
  if ([self alarmsEnabled]) {
    MemoryStore *store = [not object];
    NSString *uid = [[not userInfo] objectForKey:@"UID"];

    [self removeAlarmsforUID:uid];
    [self setAlarmsForElement:[store elementWithUID:uid]];
  }
}

- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSNumber numberWithBool:NO], [AlarmBackend backendName], nil]
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
    NSLog(@"Alarms are %@", [self alarmsEnabled] ? @"enabled" : @"disabled");
  }
  return self;
}

- (void)dealloc
{
  NSDebugLLog(@"SimpleAgenda", @"Releasing AlarmManager");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  RELEASE(_activeAlarms);
  RELEASE(backendsArray);
 [super dealloc];
}

- (void)createAlarms
{
  StoreManager *sm = [StoreManager globalManager];

  [self removeAlarms];
  if ([self alarmsEnabled]) {
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

- (NSString *)defaultBackendName
{
  return [[_defaultBackend class] backendName];
}

- (void)setDefaultBackend:(NSString *)name
{
  id bck = [AlarmManager backendForName:name];
  if (bck != nil) {
    _defaultBackend = bck;
    [[ConfigManager globalConfig] setObject:name forKey:DEFAULT_ALARM_BACKEND];
    NSLog(@"Default alarm backend is %@", name);
  }
}

- (BOOL)alarmsEnabled
{
  return [[[ConfigManager globalConfig] objectForKey:ACTIVATE_ALARMS] boolValue];
}

- (void)setAlarmsEnabled:(BOOL)value
{
  if (value)
    [self createAlarms];
  else
    [self removeAlarms];
  [[ConfigManager globalConfig] setInteger:value forKey:ACTIVATE_ALARMS];
  NSLog(@"Alarms are %@", value ? @"enabled" : @"disabled");
}
@end


@implementation AlarmBackend
+ (NSString *)backendName
{
  return @"Log backend";
}
- (void)dealloc
{
  NSDebugLLog(@"SimpleAgenda", @"Alarm backend %@ released", [[self class] backendName]);
  [super dealloc];
}
- (enum icalproperty_action)backendType
{
  return ICAL_ACTION_DISPLAY;
}
- (void)display:(Alarm *)alarm
{
  NSLog(@"%@", [alarm description]);
}
@end
