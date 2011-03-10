#import <Foundation/Foundation.h>
#import "Task.h"

@implementation Task(NSCoding)
- (void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];
  [coder encodeInt:_state forKey:@"state"];
  if (_dueDate != nil)
    [coder encodeObject:_dueDate forKey:@"dueDate"];
}
- (id)initWithCoder:(NSCoder *)coder
{
  [super initWithCoder:coder];
  _state = [coder decodeIntForKey:@"state"];
  if ([coder containsValueForKey:@"dueDate"])
    _dueDate = [[coder decodeObjectForKey:@"dueDate"] retain];
  else
    _dueDate = nil;
  return self;
}
@end

static NSArray *stateName;

@implementation Task
+ (void)initialize
{
  if ([Task class] == self)
    stateName = [[NSArray alloc] initWithObjects:_(@"None"), _(@"Started"), _(@"Completed"), _(@"Canceled"), _(@"Needs action"), nil];
}

+ (NSArray *)stateNamesArray
{
  return stateName;
}

- (id)init
{
  if ((self = [super init])) {
    _state = TK_NONE;
    _dueDate = nil;
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_dueDate);
  [super dealloc];
}

- (enum taskState)state
{
  return _state;
}

- (NSString *)stateAsString
{
  return [stateName objectAtIndex:_state];
}

- (void)setState:(enum taskState)state
{
  _state = state;
}

- (Date *)dueDate
{
  return _dueDate;
}

- (void)setDueDate:(Date *)cd
{
  DESTROY(_dueDate);
  if (cd != nil)
    ASSIGNCOPY(_dueDate, cd);
}

- (Date *)nextActivationDate
{
  /* FIXME */
  return _dueDate;
}

- (NSString *)description
{
  return [self summary];
}
@end

@implementation Task(iCalendar)
- (id)initWithICalComponent:(icalcomponent *)ic
{
  icalproperty *prop;

  if ((self = [super initWithICalComponent:ic])) {
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
	case ICAL_STATUS_NEEDSACTION:
	  [self setState:TK_NEEDSACTION];
	  break;
	default:
	  [self setState:TK_NONE];
	}
    }
    else
      [self setState:TK_NONE];
    prop = icalcomponent_get_first_property(ic, ICAL_DUE_PROPERTY);
    if (prop) 
      [self setDueDate:AUTORELEASE([[Date alloc] initWithICalTime:icalproperty_get_due(prop)])];
  }
  return self;
}

static int statusCorr[] = {ICAL_STATUS_NONE, ICAL_STATUS_INPROCESS, ICAL_STATUS_COMPLETED, ICAL_STATUS_CANCELLED, ICAL_STATUS_NEEDSACTION};

- (BOOL)updateICalComponent:(icalcomponent *)ic
{
  if (![super updateICalComponent:ic])
    return NO;
  [self deleteProperty:ICAL_STATUS_PROPERTY fromComponent:ic];
  icalcomponent_add_property(ic, icalproperty_new_status(statusCorr[[self state]]));
  [self deleteProperty:ICAL_DUE_PROPERTY fromComponent:ic];
  if (_dueDate)
    icalcomponent_add_property(ic, icalproperty_new_due([_dueDate UTCICalTime]));      
  return YES;
}

- (int)iCalComponentType
{
  return ICAL_VTODO_COMPONENT;
}
@end
