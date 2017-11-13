# -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.57)

AC_INIT(SimpleAgenda)
AC_CONFIG_SRCDIR([MemoryStore.h])
AC_CONFIG_HEADER([config.h])

old_cppflags=$CPPFLAGS
old_ldflags=$LDFLAGS

additional_include_dir=
additional_lib_dir=

AC_ARG_WITH(ical-include, [  --with-ical-include=DIR  include path for ical headers], additional_include_dir+=-I"$withval", )
AC_ARG_WITH(ical-library, [  --with-ical-library=DIR  library path for ical libraries], additional_lib_dir=-L"$withval", )
CPPFLAGS="$CPPFLAGS $additional_include_dir"
LDFLAGS="$LDFLAGS $additional_lib_dir"
AC_CHECK_HEADERS([libical/ical.h], ,[AC_CHECK_HEADERS([ical.h], ,[AC_MSG_ERROR(ical.h not found. You must have libical >= 0.27 installed.)])])
CPPFLAGS=$old_cppflags
LDFLAGS=$old_ldflags

AC_CHECK_HEADERS([uuid/uuid.h], have_libuuid=yes, have_libuuid=no)
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

AC_SUBST(have_libuuid)
AC_SUBST(have_addresses)
AC_SUBST(have_dbuskit)
AC_SUBST(additional_include_dir)
AC_SUBST(additional_lib_dir)

AH_BOTTOM([
/*
 * FIXME : this is ugly (but better than repeating
 * this ugly code in every file that needs ical.h
 */
#ifdef HAVE_LIBICAL_ICAL_H
#include <libical/ical.h>
#else
#include <ical.h>
#endif
])

AC_CONFIG_FILES([local.make])
AC_OUTPUT
