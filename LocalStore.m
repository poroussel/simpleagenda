#import <AppKit/AppKit.h>
#import "LocalStore.h"
#import "Event.h"
#import "defines.h"

#define CurrentVersion 2
#define LocalAgendaPath @"~/GNUstep/Library/SimpleAgenda"

@implementation LocalStore

- (id)initWithName:(NSString *)name forManager:(id)manager
{
  NSString *filename;
  BOOL isDir;
  int version;

  self = [super init];
  if (self) {
    _name = [name copy];
    _config = [[ConfigManager alloc] initForKey:name withParent:nil];
    if (![self eventColor])
      [self setEventColor:[NSColor yellowColor]];
    
    filename = [_config objectForKey:ST_FILE];
    _globalPath = [LocalAgendaPath stringByExpandingTildeInPath];
    _globalFile = [[NSString pathWithComponents:[NSArray arrayWithObjects:_globalPath, filename, nil]] retain];
    _modified = NO;
    _manager = manager;
    _data = [[NSMutableDictionary alloc] initWithCapacity:128];
    if ([_config objectForKey:ST_RW])
      _writable = [[_config objectForKey:ST_RW] boolValue];
    else
      [self setIsWritable:YES];
    if ([_config objectForKey:ST_DISPLAY])
      _displayed = [[_config objectForKey:ST_DISPLAY] boolValue];
    else
      [self setDisplayed:YES];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:_globalPath]) {
      if (![fm createDirectoryAtPath:_globalPath attributes:nil])
	NSLog(@"Error creating dir %@", _globalPath);
      else
	NSLog(@"Created directory %@", _globalPath);
    }
    if ([fm fileExistsAtPath:_globalFile isDirectory:&isDir] && !isDir) {
      NSSet *savedData = [NSKeyedUnarchiver unarchiveObjectWithFile:_globalFile];       
      NSEnumerator *enumerator;
      Event *apt;
      if (savedData) {
	[savedData makeObjectsPerform:@selector(setStore:) withObject:self];
	enumerator = [savedData objectEnumerator];
	while ((apt = [enumerator nextObject]))
	  [_data setValue:apt forKey:[apt UID]];
	NSLog(@"LocalStore from %@ : loaded %d appointment(s)", _globalFile, [_data count]);
	version = [_config integerForKey:ST_VERSION];
	if (version < CurrentVersion) {
	  [_config setInteger:CurrentVersion forKey:ST_VERSION];
	  [self write];
	}
      }
    }
  }
  return self;
}

+ (id)storeNamed:(NSString *)name forManager:(id)manager
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] initWithName:name 
								  forManager:manager]);
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
