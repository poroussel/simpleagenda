include $(GNUSTEP_MAKEFILES)/common.make
include local.make

# Helper variable to check if the generated files are present.
_generated_files := $(shell test -f config.h -o -f local.make && echo yes)

#
# Application
#
VERSION = 0.50
PACKAGE_NAME = SimpleAgenda
APP_NAME = SimpleAgenda
SimpleAgenda_APPLICATION_ICON = Calendar.tiff

#
# Resource files
#
SimpleAgenda_RESOURCE_FILES = \
French.lproj \
English.lproj \
Italian.lproj \
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
Sources/AppController.m \
Sources/LocalStore.m \
Sources/AppointmentEditor.m \
Sources/CalendarView.m \
Sources/StoreManager.m \
Sources/DayView.m \
Sources/Event.m \
Sources/PreferencesController.m \
Sources/HourFormatter.m \
Sources/iCalStore.m \
Sources/ConfigManager.m \
Sources/Date.m \
Sources/iCalTree.m \
Sources/DataTree.m \
Sources/Element.m \
Sources/Task.m \
Sources/TaskEditor.m \
Sources/MemoryStore.m \
Sources/GroupDAVStore.m \
Sources/WebDAVResource.m \
Sources/WeekView.m \
Sources/AppointmentView.m \
Sources/SelectionManager.m \
Sources/RecurrenceRule.m \
Sources/NSColor+SimpleAgenda.m \
Sources/Alarm.m \
Sources/AlarmManager.m \
Sources/NSString+SimpleAgenda.m \
Sources/AlarmEditor.m \
Sources/SoundBackend.m \
Sources/InvocationOperation.m

ifeq ($(ADDRESSES),yes)
SimpleAgenda_OBJC_FILES += Sources/ABStore.m
endif

ifeq ($(DBUSKIT),yes)
SimpleAgenda_OBJC_FILES += Sources/DBusBackend.m
endif

#
# Other sources
#
SimpleAgenda_OBJC_FILES += \
Sources/SimpleAgenda.m

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/application.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
