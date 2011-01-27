#import <AppKit/NSSound.h>
#import "AlarmBackend.h"
#import "Alarm.h"

@interface SoundBackend : AlarmBackend
{
  NSSound *sound;
}
@end

static NSMutableArray *sounds;

@implementation SoundBackend
+ (void)initialize
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path, *file;
  NSArray *paths, *files;
  NSEnumerator *enumerator, *fenum;

  if ([SoundBackend class] == self) {
    sounds = [[NSMutableArray alloc] initWithCapacity:8];
    paths = NSStandardLibraryPaths();
    enumerator = [paths objectEnumerator];
    while ((path = [enumerator nextObject])) {
      path = [path stringByAppendingPathComponent:@"/Sounds/"];
      files = [fm directoryContentsAtPath:path];
      if (files) {
	fenum = [files objectEnumerator];
	while ((file = [fenum nextObject])) {
	  if ([NSSound soundNamed:[file stringByDeletingPathExtension]])
	    [sounds addObject:[file stringByDeletingPathExtension]];
	}
      }
    }
  }
}

+ (NSString *)backendName
{
  return @"Sound notification";
}

- (enum icalproperty_action)backendType
{
  return ICAL_ACTION_AUDIO;
}

- (id)init
{
  self = [super init];
  if (self) {
    sound = [NSSound soundNamed:@"Basso"];
    if (!sound) {
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)display:(Alarm *)alarm
{
  [sound play];
}
@end
