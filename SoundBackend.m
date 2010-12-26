#import <AppKit/NSSound.h>
#import "AlarmBackend.h"
#import "SAAlarm.h"

@interface SoundBackend : AlarmBackend
{
  NSSound *sound;
}
@end

@implementation SoundBackend
+ (NSString *)backendName
{
  return @"Sound notification";
}

- (NSString *)backendType
{
  return SAActionSound;
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

- (void)display:(SAAlarm *)alarm
{
  [sound play];
}
@end
