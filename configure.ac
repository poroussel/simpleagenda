# -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.57)

AC_INIT(SimpleAgenda)

if test -z "$GNUSTEP_MAKEFILES"; then
  AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Find the compiler
#--------------------------------------------------------------------
if test "$CC" = ""; then
  CC=`gnustep-config --variable=CC`
fi
if test "$CPP" = ""; then
  CPP=`gnustep-config --variable=CPP`
fi
if test "$CXX" = ""; then
  CXX=`gnustep-config --variable=CXX`
fi
AC_PROG_CC
AC_PROG_CPP

MAKECC=`gnustep-config --variable=CC`
if test "$CC" != "$MAKECC"; then
  AC_MSG_ERROR([You are running configure with the compiler ($CC) set to a different value from that used by gnustep-make ($MAKECC).  Please run configure again with your environment set to match your gnustep-make])
  exit 1
fi

AC_CONFIG_SRCDIR([MemoryStore.h])
AC_CONFIG_HEADER([config.h])

old_cppflags=$CPPFLAGS
old_ldflags=$LDFLAGS

additional_include_dir=
additional_lib_dir=

AC_ARG_WITH(ical-include,
	[AS_HELP_STRING([--with-ical-include=DIR],[include path for ical headers])],
	[additional_include_dir=-I"$withval"], )
AC_ARG_WITH(ical-library,
	[AS_HELP_STRING([--with-ical-library=DIR], [library path for ical libraries])],
	[additional_lib_dir=-L"$withval"], )
CPPFLAGS="$CPPFLAGS $additional_include_dir"
LDFLAGS="$LDFLAGS $additional_lib_dir"
AC_CHECK_HEADERS([libical/ical.h], ,[AC_CHECK_HEADERS([ical.h], ,[AC_MSG_ERROR(ical.h not found. You must have libical >= 0.27 installed.)])])
CPPFLAGS=$old_cppflags
LDFLAGS=$old_ldflags

AC_CHECK_HEADERS([uuid/uuid.h])
AC_SEARCH_LIBS([uuid_generate], [uuid e2fs-uuid],
  [AC_DEFINE([HAVE_LIBUUID], [1],
    [Define to 1 if you have the required UUID library implementation])])
AC_CHECK_ADDRESSES(have_addresses=yes, have_addresses=no)

AC_ARG_ENABLE([dbuskit],
	   [AC_HELP_STRING([--disable-dbuskit],
                           [disable DBusKit based alarm notification])],
           [],
	   [enable_dbuskit=yes])
if test "x$enable_dbuskit" != xno; then
   AC_CHECK_DBUSKIT(have_dbuskit=yes, have_dbuskit=no)
else
   AC_MSG_NOTICE([DBusKit disabled])
   have_dbuskit=no
fi

AC_SUBST(have_addresses)
AC_SUBST(have_dbuskit)
AC_SUBST(additional_include_dir)
AC_SUBST(additional_lib_dir)

AH_BOTTOM([
#ifdef HAVE_LIBICAL_ICAL_H
#include <libical/ical.h>
#else
#include <ical.h>
#endif
])

AC_CONFIG_FILES([local.make])
AC_OUTPUT
