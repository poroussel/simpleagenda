#import "iCalTree.h"
#import "Event.h"
#import "Task.h"

static NSString *logKey = @"iCalTree";

@implementation iCalTree
- (id)init
{
  if ((self = [super init])) {
    _root = RETAIN([ICalComponent componentWithKind:ICalVCalendar]);
    if (!_root)
      DESTROY(self);
    [_root setText:@"2.0" forProperty:@"VERSION"];
    [_root setText:@"-//Octets//NONSGML SimpleAgenda Calendar//EN" forProperty:@"PRODID"];
  }
  return self;
}

- (void)dealloc
{
  RELEASE(_root);
  [super dealloc];
}

- (BOOL)parseString:(NSString *)string;
{
  ICalComponent *component;

  NSDebugLLog(logKey, @"iCalTree parseString %@", string);
  if (string == nil) {
    NSLog(@"No string to parse");
    return NO;
  }
  component = [ICalComponent componentWithString:string];
  if (component == nil || [component kind] != ICalVCalendar)
    return NO;
  ASSIGN(_root, component);
  return YES;
}

- (BOOL)parseData:(NSData *)data
{
  return [self parseString:[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];
}

- (NSString *)iCalTreeAsString
{
  /* OGo workaround  ? */
  [_root removeProperty:@"METHOD"];
  [_root removeErrors];
  return [_root stringValue];
}

- (NSData *)iCalTreeAsData;
{
  return [[self iCalTreeAsString] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSSet *)components
{
  NSMutableSet *work = [NSMutableSet setWithCapacity:32];
  NSEnumerator *enumerator;
  ICalComponent *component;
  Element *elt;

  enumerator = [[_root componentsOfKind:ICalVEvent] objectEnumerator];
  while ((component = [enumerator nextObject])) {
    elt = [[Event alloc] initWithICalComponent:component];
    if (elt) {
      [work addObject:elt];
      [elt release];
    }
  }
  enumerator = [[_root componentsOfKind:ICalVTodo] objectEnumerator];
  while ((component = [enumerator nextObject])) {
    elt = [[Task alloc] initWithICalComponent:component];
    if (elt) {
      [work addObject:elt];
      [elt release];
    }
  }
  // Return work directly ?
  return [NSSet setWithSet:work];
}

- (ICalComponent *)componentForEvent:(Element *)elt
{
  NSEnumerator *enumerator = [[_root componentsOfKind:[elt iCalComponentKind]] objectEnumerator];
  ICalComponent *component;
  NSString *uid = [elt UID];

  while ((component = [enumerator nextObject]))
    if ([uid isEqual:[component textForProperty:@"UID"]])
      return component;
  NSLog(@"iCalendar component not found for %@", [elt description]);
  return nil;
}

- (BOOL)add:(Element *)elt
{
  ICalComponent *component = [elt asICalComponent];

  if (!component)
    return NO;
  [_root addComponent:component];
  return YES;
}

- (BOOL)remove:(Element *)elt
{
  ICalComponent *component = [self componentForEvent:elt];

  if (!component)
    return NO;
  [_root removeComponent:component];
  return YES;
}

- (BOOL)update:(Element *)elt
{
  ICalComponent *component = [self componentForEvent:elt];

  if (!component)
    return NO;
  return [elt updateICalComponent:component];
}
@end
