# __GENERATED__ makefile marker
#

include $(GNUSTEP_MAKEFILES)/common.make
-include ../GNUmakefile.super

GNUSTEP_OBJ_DIR=./obj

TEST_TOOL_NAME =  DateTest ElementTest MemoryStoreTest RecurrenceRuleTest

ifeq ($(gcov),yes)
ADDITIONAL_OBJCFLAGS += -ftest-coverage -fprofile-arcs
ADDITIONAL_OBJCCFLAGS += -ftest-coverage -fprofile-arcs
ADDITIONAL_LDFLAGS += -ftest-coverage -fprofile-arcs
ADDITIONAL_TOOL_LIBS+=-lgcov
endif


DateTest_OBJC_FILES=DateTest.m
ElementTest_OBJC_FILES=ElementTest.m
MemoryStoreTest_OBJC_FILES=MemoryStoreTest.m
RecurrenceRuleTest_OBJC_FILES=RecurrenceRuleTest.m

-include GNUmakefile.preamble
-include make-check.mak
include $(GNUSTEP_MAKEFILES)/test-tool.make
-include GNUmakefile.postamble

after-clean::
	rm -f core core.* *.core \
	tests.log tests.sum oldtests.log oldtests.sum

