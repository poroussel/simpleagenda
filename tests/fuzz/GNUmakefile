# -*- makefile-gmake -*-
#
# libFuzzer harnesses for SimpleAgenda.
#
# Requires clang (libFuzzer + sanitizers). Build and run :
#   make
#   make fuzz                  # runs until a crash is found or ^C
#   make fuzz FUZZ_ARGS=-max_total_time=60
#
# Reproduce a crash :
#   ./obj/FuzzICal crash-<hash>
#
# Build with sanitize=no to get a plain binary (still needs libFuzzer for main).

include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_OBJ_DIR = ./obj

TOOL_NAME = FuzzICal

FuzzICal_OBJC_FILES = \
	FuzzICal.m \
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
CORPUS = corpus

fuzz:: all
	@mkdir -p $(CORPUS)
	ASAN_OPTIONS=detect_leaks=0 ./obj/FuzzICal -dict=ical.dict $(FUZZ_ARGS) $(CORPUS) seeds

after-clean::
	rm -f crash-* leak-* timeout-* oom-* slow-unit-* *.m.d *.m.o
	rm -rf $(CORPUS)
