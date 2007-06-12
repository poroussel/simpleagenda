#import <Foundation/Foundation.h>
#import <ical.h>
#import "iCalStore.h"
#import "UserDefaults.h"
#import "defines.h"

@implementation Event(iCalendar)

- (id)initWithICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;
  icalproperty *pstart;
  icalproperty *pend;
  struct icaltimetype start;
  struct icaltimetype end;
  struct icaldurationtype  diff;
  Date *date;

  [self init];
  prop = icalcomponent_get_first_property(ic, ICAL_SUMMARY_PROPERTY);
  if (!prop)
    goto init_error;
  [self setTitle:[NSString stringWithCString:icalproperty_get_summary(prop)]];

  pstart = icalcomponent_get_first_property(ic, ICAL_DTSTART_PROPERTY);
  if (!pstart)
    goto init_error;
  start = icalproperty_get_dtstart(pstart);
  date = [[Date alloc] init];
  [date setDateToTime_t:icaltime_as_timet(start)];
  [self setStartDate:date andConstrain:NO];

  pend = icalcomponent_get_first_property(ic, ICAL_DTEND_PROPERTY);
  if (!pend)
    goto init_error;
  end = icalproperty_get_dtend(pend);
  diff = icaltime_subtract(end, start);
  [self setDuration:icaldurationtype_as_int(diff) / 60];
  return self;

 init_error:
  NSLog(@"Error creating Event from iCal component");
  [self release];
  return nil;
}

@end

@implementation iCalStore

- (void)read
{
  NSData *data = [_url resourceDataUsingCache:NO];
  NSString *text;
  Event *ev;
  icalcomponent *ic;
  int number;

  if (data) {
    text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text) {
      _icomp = icalparser_parse_string([text cString]);
      if (_icomp) {
	[_set removeAllObjects];
	for (number = 0, ic = icalcomponent_get_first_component(_icomp, ICAL_VEVENT_COMPONENT); 
	     ic != NULL; ic = icalcomponent_get_next_component(_icomp, ICAL_VEVENT_COMPONENT), number++) {
	  ev = [[Event alloc] initWithICalComponent:ic];
	  [_set addObject:ev];
	}
      }
      [_set makeObjectsPerform:@selector(setStore:) withObject:self];
      NSLog(@"iCalStore from %@ : loaded %d appointment(s)", [_url absoluteString], number);
    } else
      NSLog(@"Couldn't parse data from %@", [_url absoluteString]);
  } else
    NSLog(@"No data read from %@", [_url absoluteString]);
}

- (id)initWithName:(NSString *)name forManager:(id)manager
{
  self = [super init];
  if (self) {
    _delegate = manager;
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
    if ([_params objectForKey:ST_RW])
      _writable = *(BOOL *)[_params objectForKey:ST_RW];
    else
      _writable = NO;
    _set = [[NSMutableSet alloc] initWithCapacity:128];
    [self read]; 

    if (![_url isFileURL]) {
      if ([_params objectForKey:ST_REFRESH])
	_minutesBeforeRefresh = [[_params objectForKey:ST_REFRESH] intValue];
      else
	_minutesBeforeRefresh = 1;
      _refreshTimer = [[NSTimer alloc] initWithFireDate:nil
				       interval:_minutesBeforeRefresh * 60
				       target:self selector:@selector(refreshData:) 
				       userInfo:nil repeats:YES];
      [[NSRunLoop currentRunLoop] addTimer:_refreshTimer forMode:NSDefaultRunLoopMode];
    }
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
  [_refreshTimer invalidate];
  if (_modified && [self isWritable])
    [self write];
  if (_icomp)
    icalcomponent_free(_icomp);
  [_set release];
  [_url release];
  [_params release];
  [_name release];
}

- (void)refreshData:(NSTimer *)timer
{
  /* FIXME : only refresh if data changed (using ical timestamps ?) */
  [self read];
  if ([_delegate respondsToSelector:@selector(dataChanged:)])
    [_delegate dataChanged:self];
}

- (NSArray *)scheduledAppointmentsFrom:(Date *)start to:(Date *)end
{
  NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:1];
  NSEnumerator *enumerator = [_set objectEnumerator];
  Event *apt;

  while ((apt = [enumerator nextObject])) {
    if ([apt startsBetween:start and:end])
      [array addObject:apt];
  }
  return array;
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
  return NO;
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
