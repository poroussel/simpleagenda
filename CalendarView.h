/* emacs objective-c mode -*- objc -*- */

#import <AppKit/AppKit.h>

@interface CalendarView : NSBox
{
	Date *date;
	NSPopUpButton *button;
	NSStepper *stepper;
	NSTextField *text;
	NSMatrix *matrix;
	NSFont *normalFont;
	NSFont *boldFont;
	IBOutlet id delegate;
}

- (id)initWithFrame:(NSRect)frame;

- (void)setDate:(Date *)date;
- (void)setNSDate:(NSDate *)date;
- (Date *)date;
- (NSDate *)nsDate;

- (void)setDelegate:(id)aDelegate;
- (id)delegate;

@end

@interface NSObject (CalendarViewDelegate)

- (void)dateChanged:(Date *)date;

@end
