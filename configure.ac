# -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.57)

AC_INIT(SimpleAgenda)
AC_CONFIG_SRCDIR([MemoryStore.h])
AC_CONFIG_HEADER([config.h])

AC_CHECK_HEADERS([libical/ical.h], ,[AC_CHECK_HEADERS([ical.h], ,[AC_MSG_ERROR(ical.h not found. You must have libical >= 0.27 installed.)])])
AC_CHECK_HEADERS([uuid/uuid.h], have_libuuid=yes, have_libuuid=no)
AC_CHECK_ADDRESSES(have_addresses=yes, have_addresses=no)
AC_CHECK_DBUSKIT(have_dbuskit=yes, have_dbuskit=no)
AC_SUBST(have_libuuid)
AC_SUBST(have_addresses)
AC_SUBST(have_dbuskit)

AC_CONFIG_FILES([local.make])
AC_OUTPUT
