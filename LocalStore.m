#import <AppKit/AppKit.h>
#import "LocalStore.h"
#import "Event.h"
#import "defines.h"

#define CurrentVersion 2
#define LocalAgendaPath @"~/GNUstep/Library/SimpleAgenda"

@implementation LocalStore

- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
			 [NSArchiver archivedDataWithRootObject:[NSColor yellowColor]], ST_COLOR,
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
    _modified = NO;
    _data = [[NSMutableDictionary alloc] initWithCapacity:128];
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

+ (id)createWithName:(NSString *)name
{
  id store;
  ConfigManager *cm;

  store = [self allocWithZone: NSDefaultMallocZone()];
  if (store) {
    cm = [[ConfigManager alloc] initForKey:[name copy] withParent:nil];
    [cm setObject:[name copy] forKey:ST_FILE];
    [cm setObject:[[self class] description] forKey:ST_CLASS];
    [store initWithName:name];
  }
  return store;
}

+ (NSString *)storeTypeName
{
  return @"Simple file store";
}

- (void)dealloc
{
  [self write];
  [_data release];
  [_globalFile release];
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

-(void)add:(Event *)app
{
  [app setStore:self];
  [_data setValue:app forKey:[app UID]];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

-(void)remove:(NSString *)uid
{
  [_data removeObjectForKey:uid];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

- (void)update:(NSString *)uid with:(Event *)evt;
{
  [evt setStore:self];
  [_data removeObjectForKey:uid];
  [_data setValue:evt forKey:[evt UID]];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

- (BOOL)contains:(NSString *)uid
{
  return [_data objectForKey:uid] != nil;
}

-(BOOL)isWritable
{
  return _writable;
}

- (void)setIsWritable:(BOOL)writable
{
  if (!writable)
    [self write];
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
      while ((evt = [enumerator nextObject]))
	[_data setValue:evt forKey:[evt UID]];
      NSLog(@"LocalStore from %@ : loaded %d appointment(s)", _globalFile, [_data count]);
      version = [_config integerForKey:ST_VERSION];
      if (version < CurrentVersion) {
	[_config setInteger:CurrentVersion forKey:ST_VERSION];
	[self write];
      }
    }
  }
  return YES;
}

- (BOOL)write
{
  NSSet *set = [NSSet setWithArray:[_data allValues]];
  if ([NSKeyedArchiver archiveRootObject:set toFile:_globalFile]) {
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
  NSColor *aColor = nil;
  NSData *theData =[_config objectForKey:ST_COLOR];

  if (theData)
    aColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
  return aColor;
}

- (void)setEventColor:(NSColor *)color
{
  NSData *data = [NSArchiver archivedDataWithRootObject:color];
  [_config setObject:data forKey:ST_COLOR];
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
