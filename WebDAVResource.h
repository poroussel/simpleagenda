/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import <GNUstepBase/GSXML.h>

@interface WebDAVResource : NSObject
{
  NSURL *_url;
  Class _handleClass;
  BOOL _dataChanged;
  int _httpStatus;
  NSString *_reason;
  NSString *_lastModified;
  NSString *_etag;
  NSString *_user;
  NSString *_password;
  NSData *_data;
}

- (id)initWithURL:(NSURL *)url;
- (id)initWithURL:(NSURL *)anUrl authFromURL:(NSURL *)parent;
- (BOOL)readable;
/* WARNING Destructive */
- (BOOL)writableWithData:(NSData *)data;
- (int)httpStatus;
- (NSData *)data;
- (NSURL *)url;
- (BOOL)get;
- (BOOL)delete;
- (BOOL)put:(NSData *)data attributes:(NSDictionary *)attributes;
- (BOOL)propfind:(NSData *)data attributes:(NSDictionary *)attributes;
- (void)updateAttributes;
@end

@interface NSURL(SimpleAgenda)
+ (NSURL *)URLWithString:(NSString *)string possiblyRelativeToURL:(NSURL *)base;
- (NSString *)anonymousAbsoluteString;
@end

@interface GSXMLDocument(SimpleAgenda)
- (GSXMLDocument *)strippedDocument;
@end
