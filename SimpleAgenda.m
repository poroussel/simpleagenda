/*
   Project: SimpleAgenda

   Copyright (C) 2007-2025 Philippe Roussel

   Author: Philippe Roussel <p.o.roussel@free.fr>

   Created: 2007-01-08 21:35:48 +0100 by philou

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License or any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <AppKit/AppKit.h>
#import <Renaissance/Renaissance.h>

@interface AppController : NSObject
@end

int main(int argc, const char *argv[])
{
  CREATE_AUTORELEASE_POOL(pool);
  AppController *controller;

  [NSApplication sharedApplication];

  controller = [AppController new];
  [NSApp setDelegate:controller];

  /* Load menus before the window so they are in place when the app starts. */
#ifdef GNUSTEP
  [NSBundle loadGSMarkupNamed:@"MainMenu-GNUstep" owner:controller];
#endif

  /* Load the main window; this sets all IBOutlet ivars on the controller
     so that applicationWillFinishLaunching: can use them safely. */
  [NSBundle loadGSMarkupNamed:@"Agenda" owner:controller];

  RELEASE(pool);

  {
    CREATE_AUTORELEASE_POOL(appPool);
    [NSApp run];
    RELEASE(appPool);
  }

  return 0;
}
