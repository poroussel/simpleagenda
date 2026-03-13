# __GENERATED__ makefile marker
#

include $(GNUSTEP_MAKEFILES)/common.make
-include ../GNUmakefile.super

GNUSTEP_OBJ_DIR=./obj

TEST_TOOL_NAME =  DateRangeTest DateTest ElementTest EventTest iCalTreeTest MemoryStoreTest RecurrenceRuleTest TaskTest WebDAVTest

ADDITIONAL_CPPFLAGS += -I$(GNUSTEP_MAKEFILES)/TestFramework

ifeq ($(gcov),yes)
ADDITIONAL_OBJCFLAGS += -ftest-coverage -fprofile-arcs
ADDITIONAL_OBJCCFLAGS += -ftest-coverage -fprofile-arcs
ADDITIONAL_LDFLAGS += -ftest-coverage -fprofile-arcs
ADDITIONAL_TOOL_LIBS+=-lgcov
endif


DateRangeTest_OBJC_FILES=DateRangeTest.m
DateTest_OBJC_FILES=DateTest.m
ElementTest_OBJC_FILES=ElementTest.m
EventTest_OBJC_FILES=EventTest.m
iCalTreeTest_OBJC_FILES=iCalTreeTest.m
MemoryStoreTest_OBJC_FILES=MemoryStoreTest.m
RecurrenceRuleTest_OBJC_FILES=RecurrenceRuleTest.m
TaskTest_OBJC_FILES=TaskTest.m
WebDAVTest_OBJC_FILES=WebDAVTest.m

-include GNUmakefile.preamble
-include make-check.mak
include $(GNUSTEP_MAKEFILES)/test-tool.make
-include GNUmakefile.postamble

after-clean::
	rm -f core core.* *.core \
	test_*.out test_*.err \
	tests.log tests.sum oldtests.log oldtests.sum

