include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = SimpleAgendaTests

SimpleAgendaTests_HEADER_FILES = \
	AllTests.h \
	DateTest.h

SimpleAgendaTests_OBJC_FILES = \
	../Date.m \
	DateTest.m \
	AllTests.m \
	main.m

SimpleAgendaTests_TOOL_LIBS = -lObjcUnit -lical

ADDITIONAL_OBJCFLAGS = -Wno-import -Wall

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
