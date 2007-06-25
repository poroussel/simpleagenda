/* emacs buffer mode hint -*- objc -*- */

#import "UserDefaults.h"
#import "defines.h"

@implementation UserDefaults

#define VERSION @"version"
#define CURRENT_VERSION @"0.2"

static UserDefaults *singleton;

+ (UserDefaults *)sharedInstance
{
  if (singleton == nil)
    singleton = [[UserDefaults alloc] init];
  return singleton;
}

- (void)notifyListenerForKey:(NSString *)key
{
  NSEnumerator *enumerator;
  NSMutableSet *set, *tmp;

  if (key)
    set = [_cpkey objectForKey:key];
  else {
    set = [NSMutableSet new];
    enumerator = [_cpkey objectEnumerator];
    while ((tmp = [enumerator nextObject]))
      [set unionSet:tmp];
  }
  [set makeObjectsPerformSelector:@selector(defaultDidChanged:) withObject:key];
  if (!key)
    [set release];
}

- (void)userDefaultsChanged:(NSNotification *)notification
{
  [self notifyListenerForKey:nil];
}

- (id)init
{
  self = [super init];
  if (self) {
    _cpkey = [NSMutableDictionary new];
    _defaults = [NSUserDefaults standardUserDefaults];
    if ([_defaults objectForKey:VERSION] == nil)
      [_defaults setObject:CURRENT_VERSION forKey:VERSION];

    [[NSNotificationCenter defaultCenter] addObserver:self
					  selector:@selector(userDefaultsChanged:)
					  name:@"NSUserDefaultsDidChangeNotification" object:nil];
  }
  return self;
}

- (void)dealloc
{
  [_defaults synchronize];
  [_cpkey release];
}

- (void)setHardDefaults:(NSDictionary *)def
{
  NSAssert(def != nil, @"Empty hard defaults");
  NSEnumerator *enumerator = [def keyEnumerator];
  NSString *key;

  while ((key = [enumerator nextObject])) {
    if ([_defaults objectForKey:key] == nil)
      [_defaults setObject:[def objectForKey:key] forKey:key];
  }
}

- (id)objectForKey:(NSString *)name
{
  return [_defaults objectForKey:name];
}

- (int)integerForKey:(NSString *)name
{
  return [_defaults integerForKey:name];
}

- (void)setInteger:(int)value forKey:(NSString*)key
{
  [_defaults setInteger:value forKey:key];
  [self notifyListenerForKey:key];
}

- (void)setObject:(id)value forKey:(NSString*)key
{
  [_defaults setObject:value forKey:key];
  [self notifyListenerForKey:key];
}

- (void)registerClient:(id <DefaultsConsumer>)client forKey:(NSString*)key
{
  NSMutableSet *keys = [_cpkey objectForKey:key];
  if (keys)
    [keys addObject:client];
  else {
    keys = [NSMutableSet new];
    [keys addObject:client];
  }
  [_cpkey setObject:keys forKey:key];
}

- (void)unregisterClient:(id <DefaultsConsumer>)client
{
  NSMutableSet *set;
  NSEnumerator *enumerator = [_cpkey objectEnumerator];

  while ((set = [enumerator nextObject]))
    [set removeObject:client];
}

@end

