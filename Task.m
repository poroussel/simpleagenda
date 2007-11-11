#import <Foundation/Foundation.h>
#import "Task.h"

static NSString *stateName[] = {@"None", @"Started", @"Completed", @"Canceled"};

@implementation Task(NSCoding)
-(void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];
  [coder encodeInt:_state forKey:@"state"];
  if (_completionDate != nil)
    [coder encodeObject:_completionDate forKey:@"completion"];
}
-(id)initWithCoder:(NSCoder *)coder
{
  [super initWithCoder:coder];
  _state = [coder decodeIntForKey:@"state"];
  if ([coder containsValueForKey:@"completion"])
    _completionDate = [coder decodeObjectForKey:@"completion"];
  else
    _completionDate = nil;
  return self;
}
@end

@implementation Task
+ (NSArray *)stateNamesArray
{
  return [NSArray arrayWithObjects:stateName count:4];
}

- (id)init
{
  self = [super init];
  if (self) {
    _state = TK_NONE;
    _completionDate = nil;
  }
  return self;
}
- (void)dealloc
{
  RELEASE(_completionDate);
  [super dealloc];
}
- (enum taskState)state
{
  return _state;
}
- (NSString *)stateAsString
{
  return stateName[_state];
}
- (void)setState:(enum taskState)state
{
  _state = state;
  if (state == TK_COMPLETED)
    [self setCompletionDate:[Date date]];
  else
    [self setCompletionDate:nil];
}
- (Date *)completionDate
{
  return _completionDate;
}
- (void)setCompletionDate:(Date *)cd
{
  if (_completionDate != nil)
    RELEASE(_completionDate);
  if (cd != nil)
    ASSIGNCOPY(_completionDate, cd);
  else
    _completionDate = nil;
}
@end


@implementation Task(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;

  self = [super initWithICalComponent:ic];
  if (self == nil)
    return nil;
  prop = icalcomponent_get_first_property(ic, ICAL_STATUS_PROPERTY);
  if (prop) {
    switch (icalproperty_get_status(prop))
      {
      case ICAL_STATUS_COMPLETED:
	[self setState:TK_COMPLETED];
	break;
      case ICAL_STATUS_CANCELLED:
	[self setState:TK_CANCELED];
	break;
      case ICAL_STATUS_INPROCESS:
	[self setState:TK_INPROCESS];
	break;
      default:
	[self setState:TK_NONE];
      }
  }
  else
    [self setState:TK_NONE];
  return self;
}

- (icalcomponent *)asICalComponent
{
  icalcomponent *ic = icalcomponent_new(ICAL_VTODO_COMPONENT);
  if (!ic) {
    NSLog(@"Couldn't create iCalendar component");
    return NULL;
  }
  [self updateICalComponent:ic];
  return ic;
}

static int statusCorr[] = {ICAL_STATUS_NONE, ICAL_STATUS_INPROCESS, ICAL_STATUS_COMPLETED, ICAL_STATUS_CANCELLED};

- (BOOL)updateICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;

  if (![super updateICalComponent:ic])
    return NO;
  prop = icalcomponent_get_first_property(ic, ICAL_STATUS_PROPERTY);
  if (!prop) {
    prop = icalproperty_new_status(statusCorr[[self state]]);
    icalcomponent_add_property(ic, prop);
  } else
    icalproperty_set_status(prop, statusCorr[[self state]]);
  return YES;
}

- (int)iCalComponentType
{
  return ICAL_VTODO_COMPONENT;
}
@end
