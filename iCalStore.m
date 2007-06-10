#import <Foundation/Foundation.h>
#import <ical.h>
#import "iCalStore.h"
#import "UserDefaults.h"
#import "defines.h"

@implementation iCalStore

- (void)read
{
  NSData *data = [_url resourceDataUsingCache:NO];
  NSString *text;
  icalcomponent *ic;

  if (data) {
    text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text) {
      _icomp = icalparser_parse_string([text cString]);
      if (_icomp) {
	ic = icalcomponent_get_first_component(_icomp, ICAL_VEVENT_COMPONENT);
	while (ic) {
	  ic = icalcomponent_get_next_component(_icomp, ICAL_VEVENT_COMPONENT);
	}
      }
    }
  }
}

- (id)initWithName:(NSString *)name forManager:(id)manager
{
  self = [super init];
  if (self) {
    _params = [NSMutableDictionary new];
    [_params addEntriesFromDictionary:[[UserDefaults sharedInstance] objectForKey:name]];
    _url = [[NSURL alloc] initWithString:[_params objectForKey:ST_URL]];
    if (_url == nil) {
      NSLog(@"%@ isn't a valid url", [_params objectForKey:ST_URL]);
      [_params release];
      [self release];
      return nil;
    }
    _name = [name copy];
    _modified = NO;
    if ([_params objectForKey:ST_URL])
      _writable = *(BOOL *)[_params objectForKey:ST_URL];
    else
      _writable = YES;
    [self read]; 
  }
  return self;
}

+ (id)storeNamed:(NSString *)name forManager:(id)manager
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()] initWithName:name 
								  forManager:manager]);
}

- (void)dealloc
{
  if (_modified && [self isWritable])
    [self write];
  if (_icomp)
    icalcomponent_free(_icomp);
  [_url release];
  [_params release];
  [_name release];
}

- (NSArray *)scheduledAppointmentsFrom:(Date *)start to:(Date *)end
{
  return nil;
}

- (void)addAppointment:(Event *)evt
{
}

- (void)delAppointment:(Event *)evt
{
}

- (void)updateAppointment:(Event *)evt
{
}

- (BOOL)contains:(Event *)evt
{
  return YES;
}

- (BOOL)isWritable
{
  return _writable;
}

- (BOOL)modified
{
  return _modified;
}

- (void)write
{
  NSData *data;
  char *text;
  
  if ([self isWritable] && _icomp) {
    text = icalcomponent_as_ical_string(_icomp);
    data = [NSData dataWithBytes:text length:strlen(text)];
    [_url setProperty:@"PUT" forKey:GSHTTPPropertyMethodKey];
    if ([_url setResourceData:data])
      NSLog(@"iCalStore written to %@", [_url absoluteString]);
  }
}

- (NSString *)description
{
  return _name;
}

- (NSColor *)eventColor
{
  NSColor *aColor = nil;
  NSData *theData =[_params objectForKey:ST_COLOR];

  if (theData)
    aColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
  else {
    aColor = [NSColor blueColor];
    [self setEventColor:aColor];
  }
  return aColor;
}

- (void)setEventColor:(NSColor *)color
{
  NSData *data = [NSArchiver archivedDataWithRootObject:color];
  [_params setObject:data forKey:ST_COLOR];
  [[UserDefaults sharedInstance] setObject:_params forKey:_name];
}

@end
