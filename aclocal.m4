# Shamelessly copied and adpated from GWorkspace's aclocal
AC_DEFUN(AC_CHECK_ADDRESSES,[
  
  GNUSTEP_SH_EXPORT_ALL_VARIABLES=yes
  . "$GNUSTEP_MAKEFILES/GNUstep.sh"
  unset GNUSTEP_SH_EXPORT_ALL_VARIABLES

  # For backwards compatibility, define GNUSTEP_SYSTEM_HEADERS from
  # GNUSTEP_SYSTEM_ROOT if not set yet.
  if test x"$GNUSTEP_SYSTEM_HEADERS" = x""; then
    GNUSTEP_SYSTEM_HEADERS="$GNUSTEP_SYSTEM_ROOT/Library/Headers"
  fi
  if test x"$GNUSTEP_LOCAL_HEADERS" = x""; then
    GNUSTEP_LOCAL_HEADERS="$GNUSTEP_LOCAL_ROOT/Library/Headers"
  fi

  if test x"$GNUSTEP_SYSTEM_LIBRARIES" = x""; then
    GNUSTEP_SYSTEM_LIBRARIES="$GNUSTEP_SYSTEM_ROOT/Library/Libraries"
  fi
  if test x"$GNUSTEP_LOCAL_LIBRARIES" = x""; then
    GNUSTEP_LOCAL_LIBRARIES="$GNUSTEP_LOCAL_ROOT/Library/Libraries"
  fi
  
  OLD_CFLAGS=$CFLAGS
  CFLAGS="-xobjective-c "
  CFLAGS+=`gnustep-config --objc-flags`
  PREFIX="-I"
  OLD_CPPFLAGS="$CPPFLAGS"
  CPPFLAGS="$CPPFLAGS $PREFIX$GNUSTEP_SYSTEM_HEADERS $PREFIX$GNUSTEP_LOCAL_HEADERS"

  OLD_LDFLAGS="$LD_FLAGS"
  PREFIX="-L"
  LDFLAGS="$LDFLAGS $PREFIX$GNUSTEP_SYSTEM_LIBRARIES $PREFIX$GNUSTEP_LOCAL_LIBRARIES"
  OLD_LIBS="$LIBS"
  LIBS="-lgnustep-base"
  AC_MSG_CHECKING([for Addresses framework])

  LIBS="$LIBS -lAddresses"

  AC_LINK_IFELSE(
          AC_LANG_PROGRAM(
                  [[#include <Foundation/Foundation.h>
                    #include <Addresses/Addresses.h>]],
                  [[[[ADAddressBook sharedAddressBook]];]]),
	  $1;
	  have_addresses=yes,
	  $2;
	  have_addresses=no)

  LIBS="$OLD_LIBS"
  CPPFLAGS="$OLD_CPPFLAGS"
  LDFLAGS="$OLD_LDFLAGS"
  CFLAGS="$OLD_CFLAGS"

  AC_MSG_RESULT($have_addresses)
])

AC_DEFUN(AC_CHECK_DBUSKIT,[
  
  GNUSTEP_SH_EXPORT_ALL_VARIABLES=yes
  . "$GNUSTEP_MAKEFILES/GNUstep.sh"
  unset GNUSTEP_SH_EXPORT_ALL_VARIABLES

  # For backwards compatibility, define GNUSTEP_SYSTEM_HEADERS from
  # GNUSTEP_SYSTEM_ROOT if not set yet.
  if test x"$GNUSTEP_SYSTEM_HEADERS" = x""; then
    GNUSTEP_SYSTEM_HEADERS="$GNUSTEP_SYSTEM_ROOT/Library/Headers"
  fi
  if test x"$GNUSTEP_LOCAL_HEADERS" = x""; then
    GNUSTEP_LOCAL_HEADERS="$GNUSTEP_LOCAL_ROOT/Library/Headers"
  fi

  if test x"$GNUSTEP_SYSTEM_LIBRARIES" = x""; then
    GNUSTEP_SYSTEM_LIBRARIES="$GNUSTEP_SYSTEM_ROOT/Library/Libraries"
  fi
  if test x"$GNUSTEP_LOCAL_LIBRARIES" = x""; then
    GNUSTEP_LOCAL_LIBRARIES="$GNUSTEP_LOCAL_ROOT/Library/Libraries"
  fi
  
  OLD_CFLAGS=$CFLAGS  
  CFLAGS="-xobjective-c "
  CFLAGS+=`gnustep-config --objc-flags`
  PREFIX="-I"
  OLD_CPPFLAGS="$CPPFLAGS"
  CPPFLAGS="$CPPFLAGS $PREFIX$GNUSTEP_SYSTEM_HEADERS $PREFIX$GNUSTEP_LOCAL_HEADERS"

  OLD_LDFLAGS="$LD_FLAGS"
  PREFIX="-L"
  LDFLAGS="$LDFLAGS $PREFIX$GNUSTEP_SYSTEM_LIBRARIES $PREFIX$GNUSTEP_LOCAL_LIBRARIES"
  OLD_LIBS="$LIBS"
  LIBS="-lgnustep-base"
  AC_MSG_CHECKING([for DBusKit framework])

  LIBS="$LIBS -lDBusKit"

  AC_LINK_IFELSE(
          AC_LANG_PROGRAM(
                  [[#import <Foundation/Foundation.h>
                    #import <DBusKit/DBusKit.h>]],
                  [[[[DKPort sessionBusPort]];]]),
	  $1;
	  have_dbuskit=yes,
	  $2;
	  have_dbuskit=no)

  LIBS="$OLD_LIBS"
  CPPFLAGS="$OLD_CPPFLAGS"
  LDFLAGS="$OLD_LDFLAGS"
  CFLAGS="$OLD_CFLAGS"

  AC_MSG_RESULT($have_dbuskit)
])
