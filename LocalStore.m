#import <AppKit/AppKit.h>
#import "LocalStore.h"
#import "Event.h"
#import "Task.h"
#import "defines.h"

#define CurrentVersion 2
/* FIXME : this shouldn't be hardcoded */
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
  self = [super initWithName:name];
  if (self) {
    _globalPath = [[LocalAgendaPath stringByExpandingTildeInPath] retain];
    _globalFile = [[NSString pathWithComponents:[NSArray arrayWithObjects:_globalPath, [_config objectForKey:ST_FILE], nil]] retain];
    _globalTaskFile = [[NSString stringWithFormat:@"%@.tasks", _globalFile] retain];
    [self read];
  }
  return self;
}

+ (BOOL)registerWithName:(NSString *)name
{
  ConfigManager *cm;

  cm = [[ConfigManager alloc] initForKey:name withParent:nil];
  [cm setObject:[name copy] forKey:ST_FILE];
  [cm setObject:[[self class] description] forKey:ST_CLASS];
  [cm release];
  return YES;
}

+ (NSString *)storeTypeName
{
  return @"Simple file store";
}

- (void)dealloc
{
  [self write];
  [_globalFile release];
  [_globalTaskFile release];
  [_globalPath release];
  [super dealloc];
}

- (BOOL)read
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSSet *savedData;
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
      [self fillWithElements:savedData];
      NSLog(@"LocalStore from %@ : loaded %d appointment(s)", _globalFile, [[self events] count]);
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
      [self fillWithElements:savedData];
      NSLog(@"LocalStore from %@ : loaded %d tasks(s)", _globalTaskFile, [[self tasks] count]);
    }
  }
  return YES;
}

- (BOOL)write
{
  NSSet *set;
  NSSet *tasks;

  if (![self modified])
    return YES;
  set = [NSSet setWithArray:[self events]];
  tasks = [NSSet setWithArray:[self tasks]];
  if ([NSKeyedArchiver archiveRootObject:set toFile:_globalFile] && 
      [NSKeyedArchiver archiveRootObject:tasks toFile:_globalTaskFile]) {
    NSLog(@"LocalStore written to %@", _globalFile);
    [self setModified:NO];
    return YES;
  }
  NSLog(@"Unable to write to %@, make this store read only", _globalFile);
  [self setWritable:NO];
  return NO;
}
@end
