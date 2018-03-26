#import <Foundation/Foundation.h>
#import <DBusKit/DBusKit.h>
#import "AlarmBackend.h"
#import "Alarm.h"
#import "Element.h"

@protocol Notifications
- (NSArray *)GetCapabilities;
- (NSNumber *)Notify:(NSString *)appname :(uint)replaceid :(NSString *)appicon :(NSString *)summary :(NSString *)body :(NSArray *)actions :(NSDictionary *)hints :(int)expires;
@end

@interface DBusBackend : AlarmBackend
@end

static NSString * const DBUS_BUS = @"org.freedesktop.Notifications";
static NSString * const DBUS_PATH = @"/org/freedesktop/Notifications";

@implementation DBusBackend
+ (NSString *)backendName
{
  return @"DBus desktop notification";
}

- (enum icalproperty_action)backendType
{
  return ICAL_ACTION_DISPLAY;
}

- (id)init
{
  NSConnection *c;
  id <NSObject,Notifications> remote;
  NSArray *caps;

  self = [super init];
  if (self) {
    NS_DURING
      {
	c = [NSConnection connectionWithReceivePort:[DKPort port] sendPort:AUTORELEASE([[DKPort alloc] initWithRemote:DBUS_BUS])];
	if (!c) {
	  NSLog(@"Unable to create a connection to %@", DBUS_BUS);
	  DESTROY(self);
	}
	remote = (id <NSObject,Notifications>)[c proxyAtPath:DBUS_PATH];
	if (!remote) {
	  NSLog(@"Unable to create a proxy for %@", DBUS_PATH);
	  DESTROY(self);
	}
	caps = [remote GetCapabilities];
	if (!caps) {
	  NSLog(@"No response to GetCapabilities method");
	  DESTROY(self);
	}
	[c invalidate];
      }
    NS_HANDLER
      {
	NSLog(@"%@", [localException description]);
	NSLog(@"Exception during DBus backend setup, backend disabled");
	DESTROY(self);
      }
    NS_ENDHANDLER
  }
  return self;
}

- (void)display:(Alarm *)alarm
{
    NSConnection *c;
    id <NSObject,Notifications> remote;
    Element *el = [alarm element];
    NSString *desc;

    c = [NSConnection connectionWithReceivePort:[DKPort port] sendPort:[[DKPort alloc] initWithRemote:DBUS_BUS]];
    remote = (id <NSObject,Notifications>)[c proxyAtPath:DBUS_PATH];
    if ([el text])
      desc = [NSString stringWithFormat:@"%@\n\n%@ : %@", [[[el nextActivationDate] calendarDate] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString]], [el summary], [[el text] string]];
    else
      desc = [NSString stringWithFormat:@"%@\n\n%@", [[[el nextActivationDate] calendarDate] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString]], [el summary]];
    [remote Notify:@"SimpleAgenda" 
		  :0 
		  :@"" 
		  :_(@"SimpleAgenda Reminder !") 
		  :desc
		  :[NSArray array] 
		  :[NSDictionary dictionary] 
		  :-1];
    [c invalidate];
}
@end
