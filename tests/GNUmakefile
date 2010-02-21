include $(GNUSTEP_MAKEFILES)/common.make
include ../local.make

TOOL_NAME = SimpleAgendaTests

SimpleAgendaTests_OBJC_FILES = \
	../Date.m \
	../DateRange.m \
	../RecurrenceRule.m \
	../MemoryStore.m \
	../ConfigManager.m \
	../Event.m \
	../Element.m \
	../NSString+SimpleAgenda.m \
	DateTest.m \
	ElementTest.m \
	RecurrenceRuleTest.m \
	MemoryStoreTest.m \
	AllTests.m \
	main.m

SimpleAgendaTests_TOOL_LIBS = -lObjcUnit -lical -lgnustep-gui
#ifeq(have_libuuid,yes)
SimpleAgendaTests_TOOL_LIBS += -luuid
#endif

ADDITIONAL_OBJCFLAGS = -Wno-import -Wall

include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
