#import <AppKit/AppKit.h>
#import <ChronographerSource/Date.h>
#import <ChronographerSource/Appointment.h>
#import "Appointment+Agenda.h"
#import "LocalStore.h"

#define LocalAgendaPath @"~/GNUstep/Library/SimpleAgenda"

@implementation LocalStore

- (id)initWithParameters:(NSDictionary *)params forManager:(id)manager
{
  BOOL isDir;

  self = [super init];
  if (self) {
    _filename = [params objectForKey:@"storeFilename"];
    _globalPath = [LocalAgendaPath stringByExpandingTildeInPath];
    _globalFile = [[NSString pathWithComponents:[NSArray arrayWithObjects:_globalPath, _filename, nil]] retain];
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
      NSSet *savedData = [NSKeyedUnarchiver unarchiveObjectWithFile:_globalFile];
      if (savedData) {
	[_set unionSet: savedData];
	NSLog(@"LocalStore from %@ : loaded %d appointment(s)", _globalFile, [_set count]);
      }
    }
  }
  return self;
}

+ (id)storeWithParameters:(NSDictionary *)params forManager:(id)manager
{
  
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] initWithParameters: params 
								  forManager:manager]);
}

- (void)dealloc
{
  if (_modified)
    [self write];
  [_set release];
  [_globalFile release];
}

- (NSArray *)scheduledAppointmentsFrom:(Date *)start to:(Date *)end;
{
  NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:1];
  NSEnumerator *enumerator = [_set objectEnumerator];
  Appointment *apt;

  while ((apt = [enumerator nextObject])) {
    if ([apt startsBetween:start and:end])
      [array addObject:apt];
  }
  return array;
}

-(void)addAppointment:(Appointment *)app
{
  NSLog(@"add appointment %@ on %@", [app title], [[app startDate] description]);
  [_set addObject:app];
  _modified = YES;
}

-(void)delAppointment:(Appointment *)app
{
  NSLog(@"delete appointment %@ on %@", [app title], [[app startDate] description]);
  [_set removeObject:app];
  _modified = YES;
}

-(void)updateAppointment:(Appointment *)app
{
  NSLog(@"update appointment %@ on %@", [app title], [[app startDate] description]);
  _modified = YES;
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
  return [NSString stringWithFormat:@"LocalStore in %@", _globalFile];
}

- (NSColor *)color
{
  return _color;
}

- (void)setColor:(NSColor *)color
{
  ASSIGN(_color, color);
}


@end
