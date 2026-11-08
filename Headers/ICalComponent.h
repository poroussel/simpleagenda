/* emacs buffer mode hint -*- objc -*- */

#import <Foundation/Foundation.h>

@class Date;
@class RecurrenceRule;

typedef enum
{
  ICalOtherComponent = 0,
  ICalVCalendar,
  ICalVEvent,
  ICalVTodo,
  ICalVAlarm
} ICalComponentKind;

/*
 * An iCalendar (RFC 5545) component, and the only iCalendar API the model
 * uses : libical stays inside ICalComponent.m, Date.m and RecurrenceRule.m.
 *
 * Properties are named by their iCalendar name ("SUMMARY",
 * "X-SIMPLEAGENDA-STICKY"). Setting a property replaces the first one with
 * that name (the new one goes last), and setting nil only removes it.
 * Properties the model doesn't know are kept as they are.
 *
 * Memory : a component made by +componentWithString:, +componentWithKind:
 * or -copy owns its tree. The components returned by -componentsOfKind:
 * belong to their parent, which they retain. -addComponent: gives a
 * component to its new parent, -removeComponent: gives it back : it then
 * owns its tree again. A component returned by -componentsOfKind: mustn't
 * be used once another wrapper of it was removed from its parent.
 */
@interface ICalComponent : NSObject <NSCopying>
{
  void *_ic;
  ICalComponent *_parent;
}

/* nil if string isn't an iCalendar component */
+ (ICalComponent *)componentWithString:(NSString *)string;
+ (ICalComponent *)componentWithKind:(ICalComponentKind)kind;
- (ICalComponentKind)kind;
- (NSString *)stringValue;
/* Removes the X-LIC-ERROR properties libical adds to invalid data */
- (void)removeErrors;

- (NSArray *)componentsOfKind:(ICalComponentKind)kind;
- (void)addComponent:(ICalComponent *)component;
- (void)removeComponent:(ICalComponent *)component;

- (BOOL)hasProperty:(NSString *)name;
/* Removes the first property with that name */
- (void)removeProperty:(NSString *)name;
- (void)removeAllProperties:(NSString *)name;

/*
 * The value of the first property, as text : unescaped for TEXT values
 * (SUMMARY, CATEGORIES...), as written for the others (CLASS, STATUS,
 * X-...). Enumerated values are in upper case ("PRIVATE", "IN-PROCESS")
 */
- (NSString *)textForProperty:(NSString *)name;
/* The values of all the properties with that name */
- (NSArray *)textsForProperty:(NSString *)name;
- (void)setText:(NSString *)text forProperty:(NSString *)name;

/*
 * DTSTART, DTEND, DUE, DTSTAMP, TRIGGER. A TRIGGER with a duration has no
 * date. A TZID parameter is looked up in the VTIMEZONE components of the
 * calendar, then in libical's built-in timezones : a TZID that can't be
 * found gives a local time
 */
- (Date *)dateForProperty:(NSString *)name;
/*
 * Written in UTC. A nil date is written as a null date (00000000T000000),
 * as elements decoded from old archives without DTSTAMP always were :
 * use -removeProperty: to remove the property
 */
- (void)setDate:(Date *)date forProperty:(NSString *)name;
/* date + seconds, added in UTC */
- (void)setDate:(Date *)date plusSeconds:(NSTimeInterval)seconds forProperty:(NSString *)name;
/* Seconds from the value of one date property to another's */
- (NSTimeInterval)secondsFromProperty:(NSString *)from toProperty:(NSString *)to;

/* DURATION, TRIGGER. NO if there's no such property */
- (BOOL)getDuration:(NSTimeInterval *)duration forProperty:(NSString *)name;
- (void)setDuration:(NSTimeInterval)duration forProperty:(NSString *)name;

/* RRULE */
- (RecurrenceRule *)ruleForProperty:(NSString *)name;
- (void)setRule:(RecurrenceRule *)rule forProperty:(NSString *)name;
@end
