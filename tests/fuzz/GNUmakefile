# -*- makefile-gmake -*-
#
# libFuzzer harnesses for SimpleAgenda.
#
#   FuzzICal : iCalendar parsing (iCalTree, Event, Task, Alarm...)
#   FuzzDAV  : WebDAV / GroupDAV / CalDAV client code, served by a mock
#              HTTP server (see FuzzDAV.m for the input format)
#
# Requires clang (libFuzzer + sanitizers). Build and run :
#   make
#   make fuzz-ical             # runs until a crash is found or ^C
#   make fuzz-dav FUZZ_ARGS=-max_total_time=60
#
# Reproduce a crash :
#   ./obj/FuzzICal crash-<hash>
#   ./obj/FuzzDAV crash-<hash>
#
# Build with sanitize=no to get a plain binary (still needs libFuzzer for main).

include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_OBJ_DIR = ./obj

TOOL_NAME = FuzzICal FuzzDAV

ICAL_FILES = \
	../../Alarm.m \
	../../Date.m \
	../../DateRange.m \
	../../Element.m \
	../../Event.m \
	../../HourFormatter.m \
	../../iCalTree.m \
	../../NSString+SimpleAgenda.m \
	../../RecurrenceRule.m \
	../../Task.m

FuzzICal_OBJC_FILES = \
	FuzzICal.m \
	$(ICAL_FILES)

FuzzDAV_OBJC_FILES = \
	FuzzDAV.m \
	$(ICAL_FILES) \
	../../ConfigManager.m \
	../../GroupDAVStore.m \
	../../InvocationOperation.m \
	../../MemoryStore.m \
	../../NSColor+SimpleAgenda.m \
	../../StoreManager.m \
	../../WebDAVResource.m

include ../../local.make

NEEDS_GUI = yes
ADDITIONAL_INCLUDE_DIRS += -I../..
ADDITIONAL_TOOL_LIBS += -lical

ifeq ($(sanitize),no)
FUZZ_FLAGS = -fsanitize=fuzzer
else
FUZZ_FLAGS = -fsanitize=fuzzer,address,undefined -fno-sanitize-recover=undefined
endif

ADDITIONAL_OBJCFLAGS += $(FUZZ_FLAGS) -g -O1 -fno-omit-frame-pointer
ADDITIONAL_LDFLAGS += $(FUZZ_FLAGS)

include $(GNUSTEP_MAKEFILES)/tool.make

FUZZ_ARGS ?=
FUZZ_ENV = ASAN_OPTIONS=detect_leaks=0

fuzz-ical:: FuzzICal
	@mkdir -p corpus/ical
	$(FUZZ_ENV) ./obj/FuzzICal -dict=ical.dict $(FUZZ_ARGS) corpus/ical seeds/ical

# GET responses are parsed as iCalendar : use both dictionaries
obj/dav-ical.dict: dav.dict ical.dict
	@mkdir -p obj
	cat dav.dict ical.dict > $@

fuzz-dav:: FuzzDAV obj/dav-ical.dict
	@mkdir -p corpus/dav
	$(FUZZ_ENV) ./obj/FuzzDAV -dict=obj/dav-ical.dict $(FUZZ_ARGS) corpus/dav seeds/dav

fuzz:: fuzz-ical

after-clean::
	rm -f crash-* leak-* timeout-* oom-* slow-unit-* *.m.d *.m.o
	rm -rf corpus
