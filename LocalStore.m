#import <AppKit/AppKit.h>
#import "LocalStore.h"
#import "Event.h"
#import "Task.h"
#import "defines.h"

#define CurrentVersion 2
#define LocalAgendaPath @"~/GNUstep/Library/SimpleAgenda"

@implementation LocalStore

- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
			 [NSArchiver archivedDataWithRootObject:[NSColor yellowColor]], ST_COLOR,
			 [NSArchiver archivedDataWithRootObject:[NSColor darkGrayColor]], ST_TEXT_COLOR,
		       [NSNumber numberWithBool:YES], ST_RW,
		       [NSNumber numberWithBool:YES], ST_DISPLAY,
		       [NSNumber numberWithInt:CurrentVersion], ST_VERSION,
		       nil, nil];
}

- (id)initWithName:(NSString *)name
{
  NSString *filename;

  self = [super init];
  if (self) {
    _name = [name copy];
    _config = [[ConfigManager alloc] initForKey:name withParent:nil];
    [_config registerDefaults:[self defaults]];
    filename = [_config objectForKey:ST_FILE];
    _globalPath = [LocalAgendaPath stringByExpandingTildeInPath];
    _globalFile = [[NSString pathWithComponents:[NSArray arrayWithObjects:_globalPath, filename, nil]] retain];
    _globalTaskFile = [[NSString stringWithFormat:@"%@.tasks", _globalFile] retain];
    NSLog([_globalTaskFile description]);
    _modified = NO;
    _data = [[NSMutableDictionary alloc] initWithCapacity:128];
    _tasks = [[NSMutableDictionary alloc] initWithCapacity:16];
    _writable = [[_config objectForKey:ST_RW] boolValue];
    _displayed = [[_config objectForKey:ST_DISPLAY] boolValue];
    [self read];
  }
  return self;
}

+ (id)storeNamed:(NSString *)name
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] initWithName:name]);
}

+ (BOOL)registerWithName:(NSString *)name
{
  ConfigManager *cm;

  cm = [[ConfigManager alloc] initForKey:[name copy] withParent:nil];
  [cm setObject:[name copy] forKey:ST_FILE];
  [cm setObject:[[self class] description] forKey:ST_CLASS];
  return YES;
}

+ (NSString *)storeTypeName
{
  return @"Simple file store";
}

- (void)dealloc
{
  [self write];
  [_data release];
  [_tasks release];
  [_globalFile release];
  [_globalTaskFile release];
  [_name release];
  [_config release];
  [super dealloc];
}

- (NSEnumerator *)enumerator
{
  return [_data objectEnumerator];
}

- (NSArray *)events
{
  return [_data allValues];
}
- (NSArray *)tasks
{
  return [_tasks allValues];
}

-(void)addEvent:(Event *)evt
{
  [evt setStore:self];
  [_data setValue:evt forKey:[evt UID]];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}
-(void)addTask:(Task *)task
{
  [task setStore:self];
  [_tasks setValue:task forKey:[task UID]];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

-(void)remove:(Element *)elt
{
  if ([elt isKindOfClass:[Event class]])
    [_data removeObjectForKey:[elt UID]];
  else
    [_tasks removeObjectForKey:[elt UID]];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

- (void)update:(Element *)elt;
{
  [elt setStore:self];
  if ([elt isKindOfClass:[Event class]]) {
    [_data removeObjectForKey:[elt UID]];
    [_data setValue:elt forKey:[elt UID]];
  } else {
    [_tasks removeObjectForKey:[elt UID]];
    [_tasks setValue:elt forKey:[elt UID]];
  }  
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

- (BOOL)contains:(Element *)elt
{
  if ([elt isKindOfClass:[Event class]])
    return [_data objectForKey:[elt UID]] != nil;
  return [_tasks objectForKey:[elt UID]] != nil;
}

-(BOOL)isWritable
{
  return _writable;
}

- (void)setIsWritable:(BOOL)writable
{
  _writable = writable;
  [_config setObject:[NSNumber numberWithBool:_writable] forKey:ST_RW];
}

- (BOOL)modified
{
  return _modified;
}

- (BOOL)read
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSSet *savedData;
  NSEnumerator *enumerator;
  Event *evt;
  Task *task;
  BOOL isDir;
  int version;

  if (![fm fileExistsAtPath:_globalPath]) {
    if (![fm createDirectoryAtPath:_globalPath attributes:nil]) {
      NSLog(@"Error creating dir %@", _globalPath);
      return NO;
    }
    NSLog(@"Created directory %@", _globalPath);
  }
  if ([fm fileExistsAtPath:_globalFile isDirectory:&isDir] && !isDir) {
    savedData = [NSKeyedUnarchiver unarchiveObjectWithFile:_globalFile];       
    if (savedData) {
      [savedData makeObjectsPerform:@selector(setStore:) withObject:self];
      enumerator = [savedData objectEnumerator];
      while ((evt = [enumerator nextObject])) {
	[_data setValue:evt forKey:[evt UID]];
      }
      NSLog(@"LocalStore from %@ : loaded %d appointment(s)", _globalFile, [_data count]);
      version = [_config integerForKey:ST_VERSION];
      if (version < CurrentVersion) {
	[_config setInteger:CurrentVersion forKey:ST_VERSION];
	[self write];
      }
    }
  }
  if ([fm fileExistsAtPath:_globalTaskFile isDirectory:&isDir] && !isDir) {
    savedData = [NSKeyedUnarchiver unarchiveObjectWithFile:_globalTaskFile];       
    if (savedData) {
      [savedData makeObjectsPerform:@selector(setStore:) withObject:self];
      enumerator = [savedData objectEnumerator];
      while ((task = [enumerator nextObject]))
	[_tasks setValue:task forKey:[task UID]];
      NSLog(@"LocalStore from %@ : loaded %d tasks(s)", _globalTaskFile, [_tasks count]);
    }
  }
  return YES;
}

- (BOOL)write
{
  NSSet *set = [NSSet setWithArray:[_data allValues]];
  NSSet *tasks = [NSSet setWithArray:[_tasks allValues]];
  if ([NSKeyedArchiver archiveRootObject:set toFile:_globalFile] && 
      [NSKeyedArchiver archiveRootObject:tasks toFile:_globalTaskFile]) {
    NSLog(@"LocalStore written to %@", _globalFile);
    _modified = NO;
    return YES;
  }
  NSLog(@"Unable to write to %@, make this store read only", _globalFile);
  [self setIsWritable:NO];
  return NO;
}

- (NSString *)description
{
  return _name;
}

- (NSColor *)eventColor
{
  NSData *theData =[_config objectForKey:ST_COLOR];
  return [NSUnarchiver unarchiveObjectWithData:theData];
}

- (void)setEventColor:(NSColor *)color
{
  NSData *data = [NSArchiver archivedDataWithRootObject:color];
  [_config setObject:data forKey:ST_COLOR];
}

- (NSColor *)textColor
{
  NSData *theData =[_config objectForKey:ST_TEXT_COLOR];
  return [NSUnarchiver unarchiveObjectWithData:theData];
}

- (void)setTextColor:(NSColor *)color
{
  NSData *data = [NSArchiver archivedDataWithRootObject:color];
  [_config setObject:data forKey:ST_TEXT_COLOR];
}

- (BOOL)displayed
{
  return _displayed;
}

- (void)setDisplayed:(BOOL)state
{
  _displayed = state;
  [_config setObject:[NSNumber numberWithBool:_displayed] forKey:ST_DISPLAY];
}

@end
