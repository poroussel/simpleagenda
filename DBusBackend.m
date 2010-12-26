#import <Foundation/Foundation.h>
#import <DBusKit/DBusKit.h>
#import "AlarmBackend.h"
#import "SAAlarm.h"
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

- (NSString *)backendType
{
  return SAActionDisplay;
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
	c = [NSConnection connectionWithReceivePort:[DKPort port] sendPort:[[DKPort alloc] initWithRemote:DBUS_BUS]];
	if (!c) {
	  NSLog(@"Unable to create a connection to %@", DBUS_BUS);
	  [self release];
	  self = nil;
	}
	remote = (id <NSObject,Notifications>)[c proxyAtPath:DBUS_PATH];
	if (!remote) {
	  NSLog(@"Unable to create a proxy for %@", DBUS_PATH);
	  [self release];
	  self = nil;
	}
	caps = [remote GetCapabilities];
	if (!caps) {
	  NSLog(@"No response to GetCapabilities method");
	  [self release];
	  self = nil;
	}
      }
    NS_HANDLER
      {
	NSLog([localException description]);
	NSLog(@"Exception during DBus backend setup, backend disabled");
	[self release];
	self = nil;
      }
    NS_ENDHANDLER
  }
  return self;
}

- (void)display:(SAAlarm *)alarm
{
    NSConnection *c;
    NSNumber *dnid;
    id <NSObject,Notifications> remote;
    Element *el = [alarm element];
    NSString *desc;

    c = [NSConnection connectionWithReceivePort:[DKPort port] sendPort:[[DKPort alloc] initWithRemote:DBUS_BUS]];
    remote = (id <NSObject,Notifications>)[c proxyAtPath:DBUS_PATH];
    if ([el text])
      desc = [NSString stringWithFormat:@"%@\n\n%@ : %@", [[[el nextActivationDate] calendarDate] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSDateFormatString]], [el summary], [[el text] string]];
    else
      desc = [NSString stringWithFormat:@"%@\n\n%@", [[[el nextActivationDate] calendarDate] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSDateFormatString]], [el summary]];
    dnid = [remote Notify:@"SimpleAgenda" 
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
