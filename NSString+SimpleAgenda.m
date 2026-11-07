#import <Foundation/Foundation.h>
#import "NSString+SimpleAgenda.h"

@implementation NSString(SimpleAgenda)
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
