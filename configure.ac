# -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.57)

AC_INIT(SimpleAgenda)
AC_CONFIG_SRCDIR([MemoryStore.h])
AC_CONFIG_HEADER([config.h])

AC_CHECK_HEADERS([libical/ical.h])
AC_CHECK_HEADERS([uuid/uuid.h], have_libuuid=yes, have_libuuid=no)
AC_SUBST(have_libuuid)

AC_CONFIG_FILES([local.make])
AC_OUTPUT
