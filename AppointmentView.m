/* emacs buffer mode hint -*- objc -*- */

#import "AppointmentView.h"
#import "StoreManager.h"
#import "defines.h"

static NSImage *_repeatImage;
static NSImage *_alarmImage;
static NSImage *_checkMark;

@implementation AppointmentView
+ (void)initialize
{
  _repeatImage = [NSImage imageNamed:@"repeat.tiff"];
  _alarmImage = [NSImage imageNamed:@"small-bell.tiff"];
  _checkMark = [NSImage imageNamed:@"NSMenuCheckmark"];
}

- (NSImage *)repeatImage
{
  return _repeatImage;
}

- (NSImage *)alarmImage
{
  return _alarmImage;
}

- (id)initWithFrame:(NSRect)frameRect appointment:(Event *)apt
{
  if ((self = [super initWithFrame:frameRect])) {
    ASSIGN(_apt, apt);
    [self tooltipSetup];
    [[NSNotificationCenter defaultCenter] addObserver:self 
					     selector:@selector(configChanged:) 
						 name:SAConfigManagerValueChanged 
					       object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  RELEASE(_apt);
  [super dealloc];
}

- (Event *)appointment
{
  return _apt;
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
  NSEnumerator *enm;
  MemoryStore *store;
  NSMenu *menu, *calendars;
  id <NSMenuItem> item;
  int index = 0;

  if ([event type] != NSRightMouseDown)
    return nil;

  calendars = [[NSMenu alloc] initWithTitle:_(@"Calendars")];
  [calendars setAutoenablesItems:NO];
  enm = [[StoreManager globalManager] storeEnumerator];
  while ((store = [enm nextObject])) {
    if ([store enabled] && [store writable]) {
      item = [calendars insertItemWithTitle:[store description] action:@selector(setStore:) keyEquivalent:nil atIndex:index++];
      [item setTarget:self];
      [item setRepresentedObject:store];
      if (store == [_apt store]) {
	[item setImage:_checkMark];
	[item setEnabled:NO];
      }
    }
  }
  menu = [[NSMenu alloc] initWithTitle:_(@"Appointment")];
  item = [menu insertItemWithTitle:_(@"Calendars") 
			    action:NULL
		     keyEquivalent:nil
			   atIndex:0];
  [menu setSubmenu:calendars forItem:item];
  [calendars autorelease];
  return [menu autorelease];
}

- (void)setStore:(id)sender
{
  [[StoreManager globalManager] moveElement:_apt 
				    toStore:[sender representedObject]];
}

- (void)changeSticky:(id)sender
{
  [_apt setSticky:![_apt sticky]];
  [[_apt store] update:_apt];
  [self setNeedsDisplay:YES];
}

- (void)tooltipSetup
{
  NSAttributedString *as = [_apt text];

  if ([[ConfigManager globalConfig] integerForKey:TOOLTIP] && as && [as length] > 0)
    [self setToolTip:[as string]];
  else
    [self setToolTip:nil];
}

- (void)configChanged:(NSNotification *)not
{
  NSString *key = [[not userInfo] objectForKey:@"key"];

  if ([key isEqualToString:TOOLTIP])
    [self tooltipSetup];
  else if ([key isEqualToString:ST_COLOR] || [key isEqualToString:ST_TEXT_COLOR])
    [self setNeedsDisplay:YES];
}
@end
