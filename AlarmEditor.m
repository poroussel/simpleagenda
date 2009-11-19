#import <AppKit/AppKit.h>
#import "AlarmEditor.h"

@implementation AlarmEditor
- (id)init
{
  self = [super init];
  if (self) {
    if (![NSBundle loadNibNamed:@"Alarm" owner:self]) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)show
{
  [NSApp runModalForWindow:panel];
}
@end

