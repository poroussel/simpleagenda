/* emacs buffer mode hint -*- objc -*- */

#import <AppKit/AppKit.h>
#import <ChronographerSource/Appointment.h>
#import <ChronographerSource/Date.h>
#import "AppointmentEditor.h"

@implementation AppointmentEditor


-(BOOL)editAppointment:(Appointment *)data
{
  int ret;

  [title setStringValue:[data title]];
  [duration setIntValue:[data duration] / 60];
  [durationText setIntValue:[data duration] / 60];
  [repeat selectItemAtIndex:[data interval]];

  [[description textStorage] deleteCharactersInRange:NSMakeRange(0, [[description textStorage] length])];
  [[description textStorage] appendAttributedString:[data descriptionText]];

  ret = [NSApp runModalForWindow:window];
  [window close];
  if (ret == NSOKButton) {
    Date *end = [[data startDate] copy];
    [end changeYearBy:10];
    [data setTitle:[title stringValue]];
    [data setDuration:[duration intValue] * 60];
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
