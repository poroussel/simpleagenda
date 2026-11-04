/* -*- objc -*- */

#import "ObjectTesting.h"
#import "AgendaStore.h"
#import "Alarm.h"
#import "Event.h"
#import "RecurrenceRule.h"
#import "Task.h"
#import "defines.h"

/*
 * LocalStore always writes to ~/GNUstep/Library/SimpleAgenda. To stay away
 * from the user's calendars, the files are named after the process id and
 * are removed at the end. The configuration is written to this tool's own
 * defaults domain, also removed at the end.
 */
int main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  NSString *name = [NSString stringWithFormat:@"SimpleAgendaLocalStoreTest-%d",
			     [[NSProcessInfo processInfo] processIdentifier]];
  NSString *domain = [[NSProcessInfo processInfo] processName];
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *storeFile = [[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
			   stringByAppendingPathComponent:@"SimpleAgenda"]
			  stringByAppendingPathComponent:name];
  NSString *taskFile = [storeFile stringByAppendingString:@".tasks"];
  Class cls = NSClassFromString(@"LocalStore");
  id <AgendaStore> store, reloaded;
  Event *ev, *ev2;
  Task *task, *task2;
  Alarm *alarm;
  RecurrenceRule *rule;
  Date *start, *due;

  PASS(cls != Nil, "LocalStore class exists");
  PASS([cls isUserInstanciable], "+isUserInstanciable is YES");
  PASS_EQUAL([cls storeTypeName], @"Local file", "+storeTypeName works");
  PASS([cls registerWithName:name], "+registerWithName: works");
  PASS_EQUAL([[ud objectForKey:name] objectForKey:ST_FILE], name,
	     "+registerWithName: stores the file name");
  PASS_EQUAL([[ud objectForKey:name] objectForKey:ST_CLASS], @"LocalStore",
	     "+registerWithName: stores the class name");

  store = [cls storeNamed:name];
  PASS(store != nil, "+storeNamed: works");
  PASS([store writable] && [store displayed] && [store enabled],
       "a local store is writable, displayed and enabled by default");
  PASS([store eventColor] != nil && [store textColor] != nil,
       "a local store has default colors");

  /* Reading a store without files */
  [store read];
  PASS([[store events] count] == 0 && [[store tasks] count] == 0,
       "-read on a store without files gives an empty store");
  PASS(![fm fileExistsAtPath:storeFile], "-read doesn't create the files");

  /* Nothing is written if nothing changed */
  [store write];
  PASS(![fm fileExistsAtPath:storeFile], "-write does nothing on an unmodified store");

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
  PASS([fm fileExistsAtPath:storeFile], "-write creates the events file");
  PASS([fm fileExistsAtPath:taskFile], "-write creates the tasks file");

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

  [fm removeFileAtPath:storeFile handler:nil];
  [fm removeFileAtPath:taskFile handler:nil];
  [ud removePersistentDomainForName:domain];
  [ud synchronize];
  RELEASE(arp);
  exit(EXIT_SUCCESS);
}
