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
/* The STATUS values of the task states, as libical writes them */
static NSString *statusNames[] = {@"", @"IN-PROCESS", @"COMPLETED", @"CANCELLED", @"NEEDS-ACTION"};

- (id)initWithICalComponent:(ICalComponent *)component
{
  NSString *status;
  int state;

  if ((self = [super initWithICalComponent:component])) {
    status = [component textForProperty:@"STATUS"];
    [self setState:TK_NONE];
    for (state = TK_INPROCESS; status && state <= TK_NEEDSACTION; state++)
      if ([status isEqualToString:statusNames[state]])
	[self setState:state];
    if ([component hasProperty:@"DUE"])
      [self setDueDate:[component dateForProperty:@"DUE"]];
  }
  return self;
}

- (BOOL)updateICalComponent:(ICalComponent *)component
{
  if (![super updateICalComponent:component])
    return NO;
  [component setText:statusNames[[self state]] forProperty:@"STATUS"];
  if (_dueDate)
    [component setDate:_dueDate forProperty:@"DUE"];
  else
    [component removeProperty:@"DUE"];
  return YES;
}

- (ICalComponentKind)iCalComponentKind
{
  return ICalVTodo;
}
@end
