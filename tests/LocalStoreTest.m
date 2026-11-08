/* -*- objc -*- */

#import <objc/runtime.h>
#import "ObjectTesting.h"
#import "AgendaStore.h"
#import "Alarm.h"
#import "Event.h"
#import "NSColor+SimpleAgenda.h"
#import "RecurrenceRule.h"
#import "Task.h"
#import "defines.h"
#import "Date+ICal.h"

/*
 * This test doesn't touch the real filesystem :
 *
 * - LocalStore always works in ~/GNUstep/Library/SimpleAgenda, using
 *   NSFileManager, NSKeyedArchiver and NSKeyedUnarchiver. These methods are
 *   swapped with the ones below, which work on the dictionary fakeFiles. The
 *   elements are still really archived and unarchived. NSFileManager keeps
 *   working normally outside of this directory as GNUstep itself needs it.
 *
 * - ConfigManager saves to NSUserDefaults. It's replaced by the in-memory
 *   implementation below : ConfigManager.m isn't linked with this test.
 *
 * - -[NSUserDefaults synchronize] does nothing : GNUstep calls it on its own.
 *
 * What GNUstep does before main() or to find its resources isn't covered, but
 * it only reads files.
 */
static NSString *fakeRoot;
static NSMutableDictionary *fakeFiles;
static NSMutableSet *fakeDirectories;
static BOOL failCreatingDirectories;
static NSString *failArchivingToPath;

static BOOL inFakeRoot(NSString *path)
{
  return [path hasPrefix:fakeRoot];
}

@implementation NSUserDefaults(FakeFilesystem)
- (BOOL)fake_synchronize
{
  return YES;
}
@end

@implementation NSFileManager(FakeFilesystem)
- (BOOL)fake_fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory
{
  if (!inFakeRoot(path))
    return [self fake_fileExistsAtPath:path isDirectory:isDirectory];
  if (isDirectory)
    *isDirectory = [fakeDirectories containsObject:path];
  return [fakeDirectories containsObject:path] || [fakeFiles objectForKey:path] != nil;
}
- (BOOL)fake_fileExistsAtPath:(NSString *)path
{
  if (!inFakeRoot(path))
    return [self fake_fileExistsAtPath:path];
  return [fakeDirectories containsObject:path] || [fakeFiles objectForKey:path] != nil;
}
- (BOOL)fake_createDirectoryAtPath:(NSString *)path attributes:(NSDictionary *)attributes
{
  if (!inFakeRoot(path))
    return [self fake_createDirectoryAtPath:path attributes:attributes];
  if (failCreatingDirectories)
    return NO;
  [fakeDirectories addObject:path];
  return YES;
}
@end

@implementation NSKeyedArchiver(FakeFilesystem)
+ (BOOL)fake_archiveRootObject:(id)object toFile:(NSString *)path
{
  if ([path isEqual:failArchivingToPath])
    return NO;
  [fakeFiles setObject:[self archivedDataWithRootObject:object] forKey:path];
  return YES;
}
@end

@implementation NSKeyedUnarchiver(FakeFilesystem)
+ (id)fake_unarchiveObjectWithFile:(NSString *)path
{
  NSData *data = [fakeFiles objectForKey:path];

  return data ? [self unarchiveObjectWithData:data] : nil;
}
@end

static void swapInstanceMethods(Class cls, SEL original, SEL fake)
{
  method_exchangeImplementations(class_getInstanceMethod(cls, original),
				 class_getInstanceMethod(cls, fake));
}

static void swapClassMethods(Class cls, SEL original, SEL fake)
{
  method_exchangeImplementations(class_getClassMethod(cls, original),
				 class_getClassMethod(cls, fake));
}

static void installFakeFilesystem(void)
{
  /*
   * First of all : GNUstep uses NSUserDefaults when initializing classes like
   * NSCoder, and -synchronize takes a lock by creating a directory.
   */
  swapInstanceMethods([NSUserDefaults class], @selector(synchronize),
		      @selector(fake_synchronize));
  fakeRoot = [[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
		stringByAppendingPathComponent:@"SimpleAgenda"] retain];
  fakeFiles = [NSMutableDictionary new];
  fakeDirectories = [NSMutableSet new];
  swapInstanceMethods([NSFileManager class], @selector(fileExistsAtPath:),
		      @selector(fake_fileExistsAtPath:));
  swapInstanceMethods([NSFileManager class], @selector(fileExistsAtPath:isDirectory:),
		      @selector(fake_fileExistsAtPath:isDirectory:));
  swapInstanceMethods([NSFileManager class], @selector(createDirectoryAtPath:attributes:),
		      @selector(fake_createDirectoryAtPath:attributes:));
  swapClassMethods([NSKeyedArchiver class], @selector(archiveRootObject:toFile:),
		   @selector(fake_archiveRootObject:toFile:));
  swapClassMethods([NSKeyedUnarchiver class], @selector(unarchiveObjectWithFile:),
		   @selector(fake_unarchiveObjectWithFile:));
}

/* In-memory ConfigManager, keyed configurations are dictionaries in the global one */
NSString * const SAConfigManagerValueChanged = @"SAConfigManagerValueChanged";

static NSMutableDictionary *configValues;
static ConfigManager *globalConfig;

@implementation ConfigManager
+ (void)initialize
{
  if ([ConfigManager class] == self) {
    configValues = [NSMutableDictionary new];
    globalConfig = [ConfigManager new];
  }
}
+ (ConfigManager *)globalConfig
{
  return globalConfig;
}
- (id)init
{
  if ((self = [super init]))
    _defaults = [NSMutableDictionary new];
  return self;
}
- (id)initForKey:(NSString *)key
{
  if ((self = [self init]))
    ASSIGNCOPY(_key, key);
  return self;
}
- (void)dealloc
{
  DESTROY(_defaults);
  DESTROY(_key);
  [super dealloc];
}
- (NSMutableDictionary *)values
{
  NSMutableDictionary *values;

  if (!_key)
    return configValues;
  values = [configValues objectForKey:_key];
  if (!values) {
    values = [NSMutableDictionary dictionary];
    [configValues setObject:values forKey:_key];
  }
  return values;
}
- (void)registerDefaults:(NSDictionary *)defaults
{
  [_defaults addEntriesFromDictionary:defaults];
}
- (id)objectForKey:(NSString *)key
{
  id value = [[self values] objectForKey:key];

  return value ? value : [_defaults objectForKey:key];
}
- (void)removeObjectForKey:(NSString *)key
{
  [[self values] removeObjectForKey:key];
}
- (void)setObject:(id)value forKey:(NSString *)key
{
  [[self values] setObject:value forKey:key];
}
- (int)integerForKey:(NSString *)key
{
  return [[self objectForKey:key] intValue];
}
- (void)setInteger:(int)value forKey:(NSString *)key
{
  [self setObject:[NSNumber numberWithInt:value] forKey:key];
}
- (NSColor *)colorForKey:(NSString *)key
{
  return [NSColor colorFromString:[self objectForKey:key]];
}
- (void)setColor:(NSColor *)value forKey:(NSString *)key
{
  [self setObject:[value description] forKey:key];
}
@end

/* A registered store whose files are named after the store */
static id <AgendaStore> newStore(NSString *name)
{
  Class cls = NSClassFromString(@"LocalStore");

  [cls registerWithName:name];
  return [cls storeNamed:name];
}

static NSString *pathOf(NSString *name)
{
  return [fakeRoot stringByAppendingPathComponent:name];
}

static NSString *tasksPathOf(NSString *name)
{
  return [pathOf(name) stringByAppendingString:@".tasks"];
}

int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  NSString *name = @"test";
  NSString *storeFile, *taskFile;
  ConfigManager *global;
  Class cls = NSClassFromString(@"LocalStore");
  id <AgendaStore> store, reloaded;
  Event *ev, *ev2;
  Task *task, *task2;
  Alarm *alarm;
  RecurrenceRule *rule;
  Date *start, *due;

  installFakeFilesystem();
  global = [ConfigManager globalConfig];
  storeFile = pathOf(name);
  taskFile = tasksPathOf(name);

  PASS(cls != Nil, "LocalStore class exists");
  PASS([cls isUserInstanciable], "+isUserInstanciable is YES");
  PASS_EQUAL([cls storeTypeName], @"Local file", "+storeTypeName works");
  PASS([cls registerWithName:name], "+registerWithName: works");
  PASS_EQUAL([[global objectForKey:name] objectForKey:ST_FILE], name,
	     "+registerWithName: stores the file name");
  PASS_EQUAL([[global objectForKey:name] objectForKey:ST_CLASS], @"LocalStore",
	     "+registerWithName: stores the class name");

  store = [cls storeNamed:name];
  PASS(store != nil, "+storeNamed: works");
  PASS([store writable] && [store displayed] && [store enabled],
       "a local store is writable, displayed and enabled by default");
  PASS([store eventColor] != nil && [store textColor] != nil,
       "a local store has default colors");
  PASS([fakeDirectories count] == 0 && [fakeFiles count] == 0,
       "creating a store doesn't touch the filesystem");

  /* The directory can't be created */
  failCreatingDirectories = YES;
  [fakeFiles setObject:[NSKeyedArchiver archivedDataWithRootObject:
				[NSSet setWithObject:AUTORELEASE([[Task alloc] initWithSummary:@"T"])]]
		forKey:storeFile];
  [store read];
  PASS([fakeDirectories count] == 0, "-read survives a directory that can't be created");
  PASS([[store events] count] == 0 && [[store tasks] count] == 0,
       "-read stops if the directory can't be created");
  [fakeFiles removeObjectForKey:storeFile];
  failCreatingDirectories = NO;

  /* Reading a store without files */
  [store read];
  PASS([fakeDirectories containsObject:fakeRoot], "-read creates the directory");
  PASS([[store events] count] == 0 && [[store tasks] count] == 0,
       "-read on a store without files gives an empty store");
  PASS([fakeFiles count] == 0, "-read doesn't create the files");

  /* Nothing is written if nothing changed */
  [store write];
  PASS([fakeFiles count] == 0, "-write does nothing on an unmodified store");

  /* Writing */
  start = AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string("20240615T143000")]);
  ev = AUTORELEASE([[Event alloc] initWithStartDate:start duration:90 title:@"Meeting \303\251"]);
  [ev setLocation:@"Room"];
  [ev setSticky:YES];
  [ev addCategory:@"Business"];
  [ev setText:AUTORELEASE([[NSAttributedString alloc] initWithString:@"Description"])];
  alarm = [Alarm alarm];
  [alarm setRelativeTrigger:-600];
  [ev addAlarm:alarm];
  rule = AUTORELEASE([[RecurrenceRule alloc] initWithFrequency:recurrenceFrequenceWeekly count:4]);
  [ev setRRule:rule];
  [store add:ev];

  due = AUTORELEASE([[Date alloc] initWithICalTime:icaltime_from_string("20241231")]);
  task = AUTORELEASE([[Task alloc] initWithSummary:@"Task"]);
  [task setState:TK_INPROCESS];
  [task setDueDate:due];
  [store add:task];

  PASS([store modified], "the store is modified after adding elements");
  [store write];
  PASS(![store modified], "-write resets the modified state");
  PASS([store writable], "a successful -write keeps the store writable");
  PASS([fakeFiles objectForKey:storeFile] != nil, "-write creates the events file");
  PASS([fakeFiles objectForKey:taskFile] != nil, "-write creates the tasks file");

  /* Reading from another instance */
  reloaded = [cls storeNamed:name];
  PASS([[reloaded events] count] == 0, "a new store is empty before -read");
  [reloaded read];
  PASS([[reloaded events] count] == 1, "-read loads the events");
  PASS([[reloaded tasks] count] == 1, "-read loads the tasks");
  PASS(![reloaded modified], "-read doesn't mark the store as modified");

  ev2 = (Event *)[reloaded elementWithUID:[ev UID]];
  PASS(ev2 != nil && ev2 != ev, "the event is found by UID in the new store");
  PASS([ev2 store] == reloaded, "the event belongs to the new store");
  PASS_EQUAL([ev2 summary], [ev summary], "the summary is persisted");
  PASS_EQUAL([ev2 location], @"Room", "the location is persisted");
  PASS([ev2 duration] == 90, "the duration is persisted");
  PASS([ev2 sticky], "the sticky state is persisted");
  PASS([ev2 inCategory:@"Business"], "the categories are persisted");
  PASS_EQUAL([[ev2 text] string], @"Description", "the text is persisted");
  PASS([ev2 startDate] != nil
       && [[ev2 startDate] compare:start withTime:YES] == NSOrderedSame,
       "the start date is persisted");
  PASS([[ev2 alarms] count] == 1
       && [[[ev2 alarms] objectAtIndex:0] relativeTrigger] == -600,
       "the alarms are persisted");
  PASS([[[ev2 alarms] lastObject] element] == ev2, "the alarms are linked to the event");
  PASS([ev2 rrule] != nil && [[ev2 rrule] frequency] == recurrenceFrequenceWeekly
       && [[ev2 rrule] count] == 4, "the recurrence rule is persisted");

  task2 = (Task *)[reloaded elementWithUID:[task UID]];
  PASS(task2 != nil && [task2 isKindOfClass:[Task class]], "the task is found by UID");
  PASS([task2 state] == TK_INPROCESS, "the task state is persisted");
  PASS([task2 dueDate] != nil
       && [[task2 dueDate] compare:due withTime:NO] == NSOrderedSame,
       "the task due date is persisted");

  /* Removal is persisted too */
  [reloaded remove:ev2];
  [reloaded write];
  reloaded = [cls storeNamed:name];
  [reloaded read];
  PASS([[reloaded events] count] == 0, "a removed event isn't reloaded");
  PASS([[reloaded tasks] count] == 1, "the other elements are still there");

  /* Each store has its own files */
  store = newStore(@"other");
  [store read];
  PASS([[store tasks] count] == 0, "a store doesn't read the files of another one");
  [store add:AUTORELEASE([[Task alloc] initWithSummary:@"Other"])];
  [store write];
  PASS([fakeFiles objectForKey:tasksPathOf(@"other")] != nil, "a store writes its own files");
  reloaded = [cls storeNamed:name];
  [reloaded read];
  PASS([[reloaded tasks] count] == 1, "a store doesn't write the files of another one");

  /* Failing to write the events file */
  store = newStore(@"failEvents");
  [store add:AUTORELEASE([[Task alloc] initWithSummary:@"Task"])];
  failArchivingToPath = pathOf(@"failEvents");
  [store write];
  failArchivingToPath = nil;
  PASS(![store writable], "a store becomes read only if the events can't be written");
  PASS([store modified], "a store stays modified if the events can't be written");

  /* Failing to write the tasks file */
  store = newStore(@"failTasks");
  [store add:AUTORELEASE([[Task alloc] initWithSummary:@"Task"])];
  failArchivingToPath = tasksPathOf(@"failTasks");
  [store write];
  failArchivingToPath = nil;
  PASS(![store writable], "a store becomes read only if the tasks can't be written");
  PASS([store modified], "a store stays modified if the tasks can't be written");

  /* Directories instead of files are ignored */
  store = newStore(@"directories");
  [fakeDirectories addObject:pathOf(@"directories")];
  [fakeDirectories addObject:tasksPathOf(@"directories")];
  /* Valid archives, which would be loaded if the paths weren't seen as directories */
  [fakeFiles setObject:[NSKeyedArchiver archivedDataWithRootObject:
				[NSSet setWithObject:AUTORELEASE([[Task alloc] initWithSummary:@"T1"])]]
		forKey:pathOf(@"directories")];
  [store read];
  PASS([[store tasks] count] == 0, "-read ignores a directory instead of the events file");
  [fakeFiles setObject:[fakeFiles objectForKey:pathOf(@"directories")]
		forKey:tasksPathOf(@"directories")];
  [fakeDirectories removeObject:pathOf(@"directories")];
  [fakeFiles removeObjectForKey:pathOf(@"directories")];
  [store read];
  PASS([[store tasks] count] == 0, "-read ignores a directory instead of the tasks file");

  /* An archive of events and one of tasks are read into the right lists */
  store = newStore(@"mixed");
  [fakeFiles setObject:[NSKeyedArchiver archivedDataWithRootObject:
				[NSSet setWithObject:AUTORELEASE([[Task alloc] initWithSummary:@"T"])]]
		forKey:pathOf(@"mixed")];
  [store read];
  PASS([[store tasks] count] == 1 && [[store events] count] == 0,
       "elements are sorted by class, not by file");

  /* A damaged file */
  store = newStore(@"damaged");
  [fakeFiles setObject:[@"this isn't an archive" dataUsingEncoding:NSUTF8StringEncoding]
		forKey:pathOf(@"damaged")];
  PASS_RUNS([store read], "-read survives a damaged file");
  PASS([[store events] count] == 0, "a damaged file loads nothing");

  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
