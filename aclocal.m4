# Shamelessly copied and adpated from GWorkspace's aclocal
AC_DEFUN(AC_CHECK_ADDRESSES,[
  
  GNUSTEP_SH_EXPORT_ALL_VARIABLES=yes
  . "$GNUSTEP_MAKEFILES/GNUstep.sh"
  unset GNUSTEP_SH_EXPORT_ALL_VARIABLES
  
  OLD_CFLAGS=$CFLAGS
  CFLAGS="-xobjective-c "
  CFLAGS="$CFLAGS `gnustep-config --objc-flags`"

  OLD_LIBS="$LIBS"
  LIBS=`gnustep-config --base-libs`
  LIBS="-lAddresses $LIBS"
  AC_MSG_CHECKING([for Addresses framework])

  AC_LINK_IFELSE(
          [AC_LANG_PROGRAM(
                  [[#include <Foundation/Foundation.h>
                    #include <Addresses/Addresses.h>]],
                  [[[ADAddressBook sharedAddressBook];]])],
	  $1;
	  have_addresses=yes,
	  $2;
	  have_addresses=no)

  LIBS="$OLD_LIBS"
  CFLAGS="$OLD_CFLAGS"

  AC_MSG_RESULT($have_addresses)
])

AC_DEFUN(AC_CHECK_DBUSKIT,[
  
  GNUSTEP_SH_EXPORT_ALL_VARIABLES=yes
  . "$GNUSTEP_MAKEFILES/GNUstep.sh"
  unset GNUSTEP_SH_EXPORT_ALL_VARIABLES
  
  OLD_CFLAGS=$CFLAGS  
  CFLAGS="-xobjective-c "
  CFLAGS="$CFLAGS `gnustep-config --objc-flags`"

  OLD_LIBS="$LIBS"
  LIBS=`gnustep-config --base-libs`
  LIBS="-lDBusKit $LIBS"
  AC_MSG_CHECKING([for DBusKit framework])

  AC_LINK_IFELSE(
          [AC_LANG_PROGRAM(
                  [[#import <Foundation/Foundation.h>
                    #import <DBusKit/DBusKit.h>]],
                  [[[DKPort sessionBusPort];]])],
	  $1;
	  have_dbuskit=yes,
	  $2;
	  have_dbuskit=no)

  LIBS="$OLD_LIBS"
  CFLAGS="$OLD_CFLAGS"

  AC_MSG_RESULT($have_dbuskit)
])
