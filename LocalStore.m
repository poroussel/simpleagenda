#import <AppKit/AppKit.h>
#import "LocalStore.h"
#import "Event.h"
#import "defines.h"

#define LocalAgendaPath @"~/GNUstep/Library/SimpleAgenda"

@implementation LocalStore

- (id)initWithName:(NSString *)name forManager:(id)manager
{
  NSString *filename;
  BOOL isDir;

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
    _set = [[NSMutableSet alloc] initWithCapacity:128];
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
      NSSet *savedData =  [NSKeyedUnarchiver unarchiveObjectWithFile:_globalFile];       
      if (savedData) {
	[savedData makeObjectsPerform:@selector(setStore:) withObject:self];
	[_set unionSet: savedData];
	NSLog(@"LocalStore from %@ : loaded %d appointment(s)", _globalFile, [_set count]);
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
  [_set release];
  [_globalFile release];
  [_name release];
  [_config release];
  [super dealloc];
}

- (NSEnumerator *)enumerator
{
  return [_set objectEnumerator];
}

-(void)addAppointment:(Event *)app
{
  [_set addObject:app];
  [app setStore:self];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

-(void)delAppointment:(Event *)app
{
  [_set removeObject:app];
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

-(void)updateAppointment:(Event *)app
{
  _modified = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:SADataChangedInStore object:self];
}

- (BOOL)contains:(Event *)evt
{
  return [_set containsObject:evt];
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

- (void)write
{
  if (_writable && _modified) {
    [NSKeyedArchiver archiveRootObject:_set toFile:_globalFile];
    NSLog(@"LocalStore written to %@", _globalFile);
    _modified = NO;
  }
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
