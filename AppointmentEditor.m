/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import "AppointmentEditor.h"

@implementation AppointmentEditor


-(BOOL)editAppointment:(Event *)data
{
  int ret;

  [title setStringValue:[data title]];
  [duration setFloatValue:[data duration] / 60.0];
  [durationText setFloatValue:[data duration] / 60.0];
  [repeat selectItemAtIndex:[data interval]];

  [[description textStorage] deleteCharactersInRange:NSMakeRange(0, [[description textStorage] length])];
  [[description textStorage] appendAttributedString:[data descriptionText]];

  ret = [NSApp runModalForWindow:window];
  [window close];
  if (ret == NSOKButton) {
    Date *end = [[data startDate] copy];
    [end changeYearBy:10];
    [data setTitle:[title stringValue]];
    [data setDuration:[duration floatValue] * 60.0];
    [data setInterval:[repeat indexOfSelectedItem]];
    [data setEndDate:end];
    [data setDescriptionText:[[description textStorage] copy]];
    [end release];
    return YES;
  }
  return NO;
}

-(void)validate:(id)sender
{
  [NSApp stopModalWithCode: NSOKButton];
}

-(void)cancel:(id)sender
{
  [NSApp stopModalWithCode: NSCancelButton];
}

@end
