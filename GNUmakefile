include $(GNUSTEP_MAKEFILES)/common.make
include local.make

#
# Application
#
VERSION = 0.44
PACKAGE_NAME = SimpleAgenda
APP_NAME = SimpleAgenda
SimpleAgenda_APPLICATION_ICON = Calendar.tiff

#
# Resource files
#
SimpleAgenda_RESOURCE_FILES = \
Resources/Agenda.gorm \
Resources/Appointment.gorm \
Resources/Preferences.gorm \
Resources/iCalendar.gorm \
Resources/Task.gorm \
Resources/GroupDAV.gorm \
Resources/Alarm.gorm \
Resources/Calendar.tiff \
Resources/ical-file.tiff \
Resources/repeat.tiff \
Resources/1left.tiff \
Resources/1right.tiff \
Resources/2left.tiff \
Resources/2right.tiff \
Resources/bell.tiff \
Resources/small-bell.tiff

SimpleAgenda_LANGUAGES = English French Italian

SimpleAgenda_LOCALIZED_RESOURCE_FILES = Localizable.strings

#
# Class files
#
SimpleAgenda_OBJC_FILES = \
AppController.m \
LocalStore.m \
AppointmentEditor.m \
CalendarView.m \
StoreManager.m \
DayView.m \
Event.m \
PreferencesController.m \
HourFormatter.m \
iCalStore.m \
ConfigManager.m \
Date.m \
iCalTree.m \
DataTree.m \
Element.m \
Task.m \
TaskEditor.m \
MemoryStore.m \
GroupDAVStore.m \
WebDAVResource.m \
WeekView.m \
AppointmentView.m \
SelectionManager.m \
RecurrenceRule.m \
NSColor+SimpleAgenda.m \
DateRange.m \
Alarm.m \
AlarmManager.m \
NSString+SimpleAgenda.m \
AlarmEditor.m \
SoundBackend.m \
InvocationOperation.m

ifeq ($(ADDRESSES),yes)
SimpleAgenda_OBJC_FILES += ABStore.m
endif

ifeq ($(DBUSKIT),yes)
SimpleAgenda_OBJC_FILES += DBusBackend.m
endif

#
# Other sources
#
SimpleAgenda_OBJC_FILES += \
SimpleAgenda.m 

ifeq ($(tests),yes)
SUBPROJECTS = tests
endif

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/application.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
