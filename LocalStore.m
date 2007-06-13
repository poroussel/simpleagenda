#import <AppKit/AppKit.h>
#import "LocalStore.h"
#import "Event.h"
#import "UserDefaults.h"
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
    _params = [NSMutableDictionary new];
    [_params addEntriesFromDictionary:[[UserDefaults sharedInstance] objectForKey:name]];

    if (![self eventColor])
      [self setEventColor:[NSColor yellowColor]];

    filename = [_params objectForKey:ST_FILE];
    _globalPath = [LocalAgendaPath stringByExpandingTildeInPath];
    _globalFile = [[NSString pathWithComponents:[NSArray arrayWithObjects:_globalPath, filename, nil]] retain];
    _modified = NO;
    _manager = manager;
    _set = [[NSMutableSet alloc] initWithCapacity:128];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:_globalPath]) {
      if (![fm createDirectoryAtPath:_globalPath attributes:nil])
	NSLog(@"Error creating dir %@", _globalPath);
      else
	NSLog(@"Created directory %@", _globalPath);
    }
    if ([fm fileExistsAtPath:_globalFile isDirectory:&isDir] && !isDir) {
      /*
       * Code needed to translate old Appointment objects to Events
       * To be replaced shortly by
       * [NSKeyedUnarchiver unarchiveObjectWithFile:_globalFile]
       */
      NSData *data = [NSData dataWithContentsOfFile:_globalFile];
      NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
      [unarchiver setClass:[Event class] forClassName:@"Appointment"];
      NSSet *savedData = RETAIN([unarchiver decodeObjectForKey: @"root"]);
      [unarchiver finishDecoding];
      [unarchiver release];

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
  if (_modified)
    [self write];
  [_set release];
  [_globalFile release];
  [_name release];
  [_params release];
}

- (NSArray *)scheduledAppointmentsFrom:(Date *)start to:(Date *)end;
{
  NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:1];
  NSEnumerator *enumerator = [_set objectEnumerator];
  Event *apt;

  while ((apt = [enumerator nextObject])) {
    if ([apt startsBetween:start and:end])
      [array addObject:apt];
  }
  return array;
}

-(void)addAppointment:(Event *)app
{
  //NSLog(@"add appointment %@ on %@", [app title], [[app startDate] description]);
  [_set addObject:app];
  [app setStore:self];
  _modified = YES;
}

-(void)delAppointment:(Event *)app
{
  //NSLog(@"delete appointment %@ on %@", [app title], [[app startDate] description]);
  [_set removeObject:app];
  _modified = YES;
}

-(void)updateAppointment:(Event *)app
{
  //NSLog(@"update appointment %@ on %@", [app title], [[app startDate] description]);
  _modified = YES;
}

- (BOOL)contains:(Event *)evt
{
  if ([_set member:evt])
    return YES;
  return NO;
}

-(BOOL)isWritable
{
  return YES;
}

- (BOOL)modified
{
  return _modified;
}

- (void)write
{
  NSLog(@"LocalStore written to %@", _globalFile);
  [NSKeyedArchiver archiveRootObject:_set toFile:_globalFile];
}

- (NSString *)description
{
  return _name;
}

- (NSColor *)eventColor
{
  NSColor *aColor = nil;
  NSData *theData =[_params objectForKey:ST_COLOR];

  if (theData)
    aColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
  return aColor;
}

- (void)setEventColor:(NSColor *)color
{
  NSData *data = [NSArchiver archivedDataWithRootObject:color];
  [_params setObject:data forKey:ST_COLOR];
  [[UserDefaults sharedInstance] setObject:_params forKey:_name];
}


@end
