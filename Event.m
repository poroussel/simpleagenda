/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>
#import "Event.h"

@implementation Date(NSCoding)
-(void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeInt:year forKey:@"year"];
  [coder encodeInt:month forKey:@"month"];
  [coder encodeInt:day forKey:@"day"];
  [coder encodeInt:minute forKey:@"minute"];
}
-(id)initWithCoder:(NSCoder *)coder
{
  [super init];
  year = [coder decodeIntForKey:@"year"];
  month = [coder decodeIntForKey:@"month"];
  day = [coder decodeIntForKey:@"day"];
  minute = [coder decodeIntForKey:@"minute"];
  return self;
}
@end

@implementation Event(NSCoding)

-(void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:title forKey:@"title"];
  // FIXME : we encode a simple string, losing the attributes
  [coder encodeObject:[descriptionText string] forKey:@"descriptionText"];
  [coder encodeObject:startDate forKey:@"sdate"];
  [coder encodeObject:endDate forKey:@"edate"];
  [coder encodeInt:interval forKey:@"interval"];
  [coder encodeInt:frequency forKey:@"frequency"];
  [coder encodeInt:duration forKey:@"duration"];
  [coder encodeInt:scheduleLevel forKey:@"scheduleLevel"];
  [coder encodeObject:location forKey:@"location"];
}

-(id)initWithCoder:(NSCoder *)coder
{
  title = [[coder decodeObjectForKey:@"title"] retain];
  descriptionText = [[[NSAttributedString alloc] initWithString:[coder decodeObjectForKey:@"descriptionText"]] retain];
  startDate = [[coder decodeObjectForKey:@"sdate"] retain];
  endDate = [[coder decodeObjectForKey:@"edate"] retain];
  interval = [coder decodeIntForKey:@"interval"];
  frequency = [coder decodeIntForKey:@"frequency"];
  duration = [coder decodeIntForKey:@"duration"];
  scheduleLevel = [coder decodeIntForKey:@"scheduleLevel"];
  location = [[coder decodeObjectForKey:@"location"] retain];
  return self;
}

@end

@implementation Event

- (id)initWithStartDate:(Date *)start duration:(int)minutes title:(NSString *)aTitle
{
  [self init];
  [self setStartDate:start andConstrain:NO];
  [self setTitle:aTitle];
  [self setDuration:minutes];
  return self;
}

- (void)dealloc
{
  [location release];
  [super dealloc];
}

- (BOOL)startsBetween:(Date *)start and:(Date *)end
{
  /* FIXME : do something for recurrent appointments */
  if ([startDate isEqual:start] == YES)
    return YES;
  if ([startDate compare:start] == NSOrderedDescending && [startDate compare:end] == NSOrderedAscending) {
    return YES;
  }
  return NO;
}

- (id <AgendaStore>)store
{
  return _store;
}

- (void)setStore:(id <AgendaStore>)store
{
  _store = store;
}

- (NSString *)location
{
  return location;
}

- (void)setLocation:(NSString *)aLocation
{
  ASSIGN(location, aLocation);
}

@end

