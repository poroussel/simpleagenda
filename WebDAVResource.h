/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import <GNUstepBase/GSXML.h>

@interface WebDAVResource : NSObject
{
  NSURL *_url;
  Class _handleClass;
  NSLock *_lock;
  BOOL _dataChanged;
  int _httpStatus;
  NSString *_reason;
  NSString *_lastModified;
  NSString *_etag;
  NSString *_user;
  NSString *_password;
  NSData *_data;
  BOOL _debug;
}

- (id)initWithURL:(NSURL *)url;
- (id)initWithURL:(NSURL *)anUrl authFromURL:(NSURL *)parent;
- (void)setDebug:(BOOL)debug;
- (BOOL)readable;
/* WARNING Destructive */
- (BOOL)writableWithData:(NSData *)data;
- (int)httpStatus;
- (NSData *)data;
- (NSString *)reason;
- (BOOL)dataChanged;
- (NSURL *)url;
- (BOOL)options;
- (BOOL)get;
- (BOOL)delete;
- (BOOL)put:(NSData *)data attributes:(NSDictionary *)attributes;
- (BOOL)propfind:(NSData *)data attributes:(NSDictionary *)attributes;
- (void)updateAttributes;
- (void)setUser:(NSString *)user password:(NSString *)password;
@end

@interface NSURL(SimpleAgenda)
+ (BOOL)stringIsValidURL:(NSString *)string;
+ (NSURL *)URLWithString:(NSString *)string possiblyRelativeToURL:(NSURL *)base;
- (NSURL *)redirection;
@end

@interface GSXMLDocument(SimpleAgenda)
- (GSXMLDocument *)strippedDocument;
@end
