#import <AppKit/AppKit.h>
#import "MemoryStore.h"
#import "Event.h"
#import "Task.h"
#import "defines.h"

NSString * const SADataChangedInStore = @"SADataDidChangedInStore";
NSString * const SAStatusChangedForStore = @"SAStatusChangedForStore";
NSString * const SAElementAddedToStore = @"SAElementAddedToStore";
NSString * const SAElementRemovedFromStore = @"SAElementRemoveFromStore";
NSString * const SAElementUpdatedInStore = @"SAElementUpdatedInStore";

@implementation MemoryStore
- (NSDictionary *)defaults
{
  return nil;
}

- (id)initWithName:(NSString *)name
{
  self = [super init];
  if (self) {
    _name = [name copy];
    _config = [[ConfigManager alloc] initForKey:name withParent:nil];
    [_config registerDefaults:[self defaults]];
    _modified = NO;
    _enabled = YES;
    _data = [[NSMutableDictionary alloc] initWithCapacity:128];
    _tasks = [[NSMutableDictionary alloc] initWithCapacity:16];
    _writable = [[_config objectForKey:ST_RW] boolValue];
    _displayed = [[_config objectForKey:ST_DISPLAY] boolValue];
  }
  return self;
}

+ (id)storeNamed:(NSString *)name
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] initWithName:name]);
}

+ (BOOL)registerWithName:(NSString *)name
{
  return NO;
}
+ (NSString *)storeTypeName
{
  return nil;
}

- (void)dealloc
{
  [_data release];
  [_tasks release];
  [_name release];
  [_config release];
  [super dealloc];
}

- (NSArray *)events
{
  return [_data allValues];
}
- (NSArray *)tasks
{
  return [_tasks allValues];
}

- (Element *)elementWithUID:(NSString *)uid
{
  if ([_data objectForKey:uid] != nil)
    return [_data objectForKey:uid];
  if ([_tasks objectForKey:uid] != nil)
    return [_tasks objectForKey:uid];
  return nil;
}

/* Should be used only when loading data */
- (void)fillWithElements:(NSSet *)set
{
  NSEnumerator *enumerator = [set objectEnumerator];
  Element *elt;

  while ((elt = [enumerator nextObject])) {
    [elt setStore:self];
    if ([elt isKindOfClass:[Event class]])
      [_data setValue:elt forKey:[elt UID]];
    else
      [_tasks setValue:elt forKey:[elt UID]];
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

- (void)add:(Element *)elt
{
  NSString *uid = [elt UID];
  
  if (uid == nil) {
    /* FIXME : this has nothing to do here */
    [elt setClassification: ICAL_CLASS_PUBLIC];
    [elt generateUID];
    uid = [elt UID];
  }
  [elt setStore:self];
  [elt setDateStamp:[Date now]];
  if ([elt isKindOfClass:[Event class]])
    [_data setValue:elt forKey:uid];
  else
    [_tasks setValue:elt forKey:uid];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SAElementAddedToStore 
					              object:self
					            userInfo:[NSDictionary dictionaryWithObject:uid forKey:@"UID"]];
}

- (void)remove:(Element *)elt
{
  NSString *uid = [elt UID];

  if ([elt isKindOfClass:[Event class]])
    [_data removeObjectForKey:uid];
  else
    [_tasks removeObjectForKey:uid];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SAElementRemovedFromStore 
					              object:self
					            userInfo:[NSDictionary dictionaryWithObject:uid forKey:@"UID"]];
}

- (void)update:(Element *)elt;
{
  [elt setDateStamp:[Date now]];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SAElementUpdatedInStore 
					              object:self
					            userInfo:[NSDictionary dictionaryWithObject:[elt UID] forKey:@"UID"]];
}

- (BOOL)contains:(Element *)elt
{
  if ([elt isKindOfClass:[Event class]])
    return [_data objectForKey:[elt UID]] != nil;
  return [_tasks objectForKey:[elt UID]] != nil;
}

-(BOOL)writable
{
  return _writable;
}
- (void)setWritable:(BOOL)writable
{
  _writable = writable;
  [_config setObject:[NSNumber numberWithBool:_writable] forKey:ST_RW];
  [[NSNotificationCenter defaultCenter] postNotificationName:SAStatusChangedForStore object:self];
}

- (BOOL)modified
{
  return _modified;
}
- (void)setModified:(BOOL)modified
{
  _modified = modified;
}
- (NSString *)description
{
  return _name;
}

- (NSColor *)eventColor
{
  return [NSUnarchiver unarchiveObjectWithData:[_config objectForKey:ST_COLOR]];
}
- (void)setEventColor:(NSColor *)color
{
  [_config setObject:[NSArchiver archivedDataWithRootObject:color] forKey:ST_COLOR];
}

- (NSColor *)textColor
{
  return [NSUnarchiver unarchiveObjectWithData:[_config objectForKey:ST_TEXT_COLOR]];
}
- (void)setTextColor:(NSColor *)color
{
  [_config setObject:[NSArchiver archivedDataWithRootObject:color] forKey:ST_TEXT_COLOR];
}

- (BOOL)displayed
{
  return _displayed;
}
- (void)setDisplayed:(BOOL)state
{
  _displayed = state;
  [_config setObject:[NSNumber numberWithBool:_displayed] forKey:ST_DISPLAY];
  [[NSNotificationCenter defaultCenter] postNotificationName:SAStatusChangedForStore object:self];
}

- (BOOL)enabled
{
  return _enabled;
}
- (void)setEnabled:(BOOL)state
{
  _enabled = state;
  NSLog(@"Store %@ %@", _name, state ? @"enabled" : @"disabled");
  [[NSNotificationCenter defaultCenter] postNotificationName:SAStatusChangedForStore object:self];
}
@end
