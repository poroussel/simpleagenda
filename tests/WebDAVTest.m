/* -*- objc -*- */

#import "ObjectTesting.h"
#import "WebDAVResource.h"

int main ()
{
  NSString *baseURL = @"http://droopy.octets.fr/calendar/test";
  WebDAVResource *dav;
  NSURL *url;

  CREATE_AUTORELEASE_POOL(arp);

  test_alloc(@"WebDAVResource");

  dav = [[WebDAVResource alloc] initWithURL:nil
				   username:nil
				   password:nil];
  PASS(dav != nil, "-initWithURL with nil URL works");
  test_NSObject(@"WebDAVResource", [NSArray arrayWithObject:dav]);
  RELEASE(dav);

  url = [NSURL URLWithString:baseURL];
  PASS(url != nil && [[url absoluteString] isEqualToString:baseURL], "+URLWithString works");

  dav = [[WebDAVResource alloc] initWithURL:url
				   username:nil
				   password:nil];
  PASS(dav != nil, "-initWithURL with simple URL works");
  PASS([[[dav url] absoluteString] isEqualToString:baseURL], "-initWithURL with simple URL keeps URL unchanged");
  RELEASE(dav);

  dav = [[WebDAVResource alloc] initWithURL:url
				   username:@"user"
				   password:@"password"];
  PASS(dav != nil, "-initWithURL with user/password works");
  PASS([[[dav url] user] isEqualToString:@"user"] &&
       [[[dav url] password] isEqualToString:@"password"], "-initWithURL with user/password keeps user/password");
  RELEASE(dav);

  dav = [[WebDAVResource alloc] initWithURL:url
				   username:@"p.o.roussel@free.fr"
				   password:@"$p@ssword"];
  PASS(dav != nil, "-initWithURL with user/password needing % escaping works");
  PASS([[[dav url] absoluteString] isEqualToString:@"http://p.o.roussel%40free.fr:$p%40ssword@droopy.octets.fr/calendar/test"], "-initWithURL URL is correctly escaped");
  PASS([[[dav url] user] isEqualToString:@"p.o.roussel@free.fr"] &&
       [[[dav url] password] isEqualToString:@"$p@ssword"], "-initWithURL user/password encoding works");
  PASS([[[dav url] anonymousAbsoluteString] isEqualToString:@"http://xxx:yyy@droopy.octets.fr/calendar/test"], "-anonymousAbsoluteString works")
  RELEASE(dav);


  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
