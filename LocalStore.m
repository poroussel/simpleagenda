#import <AppKit/AppKit.h>
#import "AgendaStore.h"
#import "Event.h"
#import "Task.h"
#import "defines.h"

@interface LocalStore : MemoryStore <AgendaStore>
{
  NSString *_globalPath;
  NSString *_globalFile;
  NSString *_globalTaskFile;
}
@end

@implementation LocalStore
- (NSDictionary *)defaults
{
  return [NSDictionary dictionaryWithObjectsAndKeys:[[NSColor yellowColor] description], ST_COLOR,
		       [[NSColor darkGrayColor] description], ST_TEXT_COLOR,
		       [NSNumber numberWithBool:YES], ST_RW,
		       [NSNumber numberWithBool:YES], ST_DISPLAY,
		       [NSNumber numberWithBool:YES], ST_ENABLED,
		       nil, nil];
}

- (id)initWithName:(NSString *)name
{
  self = [super initWithName:name];
  if (self) {
    _globalPath = [[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] 
		     stringByAppendingPathComponent:@"SimpleAgenda"] retain];
    _globalFile = [[_globalPath stringByAppendingPathComponent:[[self config] objectForKey:ST_FILE]] retain];
    _globalTaskFile = [[NSString stringWithFormat:@"%@.tasks", _globalFile] retain];
    [self read];
  }
  return self;
}

+ (BOOL)isUserInstanciable
{
  return YES;
}

+ (BOOL)registerWithName:(NSString *)name
{
  ConfigManager *cm;

  cm = [[ConfigManager alloc] initForKey:name];
  [cm setObject:[name copy] forKey:ST_FILE];
  [cm setObject:[[self class] description] forKey:ST_CLASS];
  [cm release];
  return YES;
}

+ (NSString *)storeTypeName
{
  return @"Local file";
}

- (void)dealloc
{
  [_globalFile release];
  [_globalTaskFile release];
  [_globalPath release];
  [super dealloc];
}

- (void)read
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSSet *savedData;
  BOOL isDir;

  if (![fm fileExistsAtPath:_globalPath]) {
    if (![fm createDirectoryAtPath:_globalPath attributes:nil]) {
      NSLog(@"Error creating dir %@", _globalPath);
      return;
    }
    NSLog(@"Created directory %@", _globalPath);
  }
  if ([fm fileExistsAtPath:_globalFile isDirectory:&isDir] && !isDir) {
    savedData = [NSKeyedUnarchiver unarchiveObjectWithFile:_globalFile];
    if (savedData) {
      [self fillWithElements:savedData];
      NSLog(@"LocalStore from %@ : loaded %lu appointment(s)", _globalFile, [[self events] count]);
    }
  }
  if ([fm fileExistsAtPath:_globalTaskFile isDirectory:&isDir] && !isDir) {
    savedData = [NSKeyedUnarchiver unarchiveObjectWithFile:_globalTaskFile];
    if (savedData) {
      [self fillWithElements:savedData];
      NSLog(@"LocalStore from %@ : loaded %lu tasks(s)", _globalTaskFile, [[self tasks] count]);
    }
  }
}

- (void)write
{
  if (![self modified])
    return;
  if ([NSKeyedArchiver archiveRootObject:[NSSet setWithArray:[self events]] toFile:_globalFile] &&
      [NSKeyedArchiver archiveRootObject:[NSSet setWithArray:[self tasks]] toFile:_globalTaskFile]) {
    NSLog(@"LocalStore written to %@", _globalFile);
    [self setModified:NO];
  } else {
    NSLog(@"Unable to write to %@, make this store read only", _globalFile);
    [self setWritable:NO];
  }
}
@end
