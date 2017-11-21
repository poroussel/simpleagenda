#import <Foundation/Foundation.h>
#import "NSString+SimpleAgenda.h"
#import "config.h"
#ifdef HAVE_UUID_UUID_H
#include <uuid/uuid.h>
#else
#import "Date.h"
#endif

@implementation NSString(SimpleAgenda)
+ (NSString *)uuid
{
#ifdef HAVE_LIBUUID
  uuid_t uuid;
  char uuid_str[37];

  uuid_generate(uuid);
  uuid_unparse(uuid, uuid_str);
  return [NSString stringWithCString:uuid_str];
#else
  Date *now = [Date now];
  static Date *lastDate;
  static int counter;

  if (!lastDate)
    ASSIGNCOPY(lastDate, now);
  else {
    if (![lastDate compare:now withTime:YES])
      counter++;
    else {
      ASSIGNCOPY(lastDate, now);
      counter = 0;
    }
  }
  return [NSString stringWithFormat:@"%@-%d-%@", [now description], counter, [[NSHost currentHost] address]];
#endif
}

- (BOOL)isValidURL
{
  BOOL valid = NO;
  NSURL *url;

  NS_DURING
    {
      /* We want an absolute URL */
      if ((url = [NSURL URLWithString:self]) && [url scheme])
	  valid = YES;
    }
  NS_HANDLER
    {
      NSDebugLLog(@"SimpleAgenda", @"<%@> isn't a valid URL", self);
    }
  NS_ENDHANDLER
    return valid;
}
@end
