include $(GNUSTEP_MAKEFILES)/common.make

#
# Application
#
VERSION = 0.38
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
Resources/Calendar.tiff \
Resources/ical-file.tiff \
Resources/repeat.tiff \
Resources/1left.tiff \
Resources/1right.tiff \
Resources/2left.tiff \
Resources/2right.tiff 

#
# Header files
#
SimpleAgenda_HEADER_FILES = \
AppController.h \
AgendaStore.h \
LocalStore.h \
AppointmentEditor.h \
CalendarView.h \
StoreManager.h \
DayView.h \
Event.h \
PreferencesController.h \
HourFormatter.h \
UserDefaults.h \
iCalStore.h \
ConfigManager.h \
Date.h \
iCalTree.h \
DataTree.h \
Element.h \
Task.h \
TaskEditor.h \
MemoryStore.h \
GroupDAVStore.h \
WebDAVResource.h \
WeekView.h \
AppointmentView.h \
SelectionManager.h \
RecurrenceRule.h \
NSColor+SimpleAgenda.h \
config.h

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
NSColor+SimpleAgenda.m

#
# Other sources
#
SimpleAgenda_OBJC_FILES += \
SimpleAgenda.m 

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
