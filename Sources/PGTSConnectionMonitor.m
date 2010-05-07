//
// PGTSConnectionMonitor.m
// BaseTen
//
// Copyright (C) 2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
// us at sales@karppinen.fi. Without an additional license, this software
// may be distributed only in compliance with the GNU General Public License.
//
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License, version 2.0,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
// $Id$
//

#import "PGTSConnectionMonitor.h"
#import "PGTSAdditions.h"
#import "PGTSProbes.h"
#import "BXLogger.h"
#import "BXArraySize.h"
#import "BXConstants.h"
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOMessage.h>
#import <AppKit/AppKit.h>


static NSString* kPGTSConnectionMonitorSleepNotification = @"PGTSConnectionMonitorSleepNotification";
static NSString* kPGTSConnectionMonitorAwakeNotification = @"PGTSConnectionMonitorAwakeNotification";
static NSString* kPGTSConnectionMonitorExitNotification = @"PGTSConnectionMonitorExitNotification";


@interface PGTSFoundationConnectionMonitor : PGTSConnectionMonitor
{
	io_connect_t mIOPowerSession;
}
- (io_connect_t) IOPowerSession;
@end


@interface PGTSAppKitConnectionMonitor : PGTSConnectionMonitor
{
}
@end


/**
 * \internal
 * \brief A class cluster for handling various notifications provided by AppKit-specific classes.
 *
 * This class and its subclasses are thread-safe.
 */
@implementation PGTSConnectionMonitor
+ (id) sharedInstance
{
	__strong static id sharedInstance = nil;
	if (! sharedInstance)
	{
		@synchronized (self)
		{
			if (! sharedInstance)
			{
				if (NSClassFromString (@"NSApplication"))
					sharedInstance = [[PGTSAppKitConnectionMonitor alloc] init];
				else
					sharedInstance = [[PGTSFoundationConnectionMonitor alloc] init];
			}
		}
	}
	return sharedInstance;
}

- (void) monitorConnection: (PGTSConnection *) connection
{
	[self doesNotRecognizeSelector: _cmd];
}

- (void) unmonitorConnection: (PGTSConnection *) connection
{
	[self doesNotRecognizeSelector: _cmd];
}
@end


@implementation PGTSFoundationConnectionMonitor
static void
ProcessWillExit ()
{
	[[NSNotificationCenter defaultCenter] postNotificationName: kPGTSConnectionMonitorExitNotification object: nil];
}


static void
WorkspaceWillSleep (void* refCon, io_service_t service, natural_t messageType, void* messageArgument)
{
	
	PGTSFoundationConnectionMonitor* monitor = (id) refCon;
    switch (messageType)
    {
        case kIOMessageCanSystemSleep:
        case kIOMessageSystemWillSleep:
		{
			PGTS_BEGIN_SLEEP_PREPARATION ();
			NSString* note = kPGTSConnectionMonitorSleepNotification;
			[[NSNotificationCenter defaultCenter] postNotificationName: note object: monitor];
            IOAllowPowerChange ([monitor IOPowerSession], (long) messageArgument);
			PGTS_END_SLEEP_PREPARATION ();
            break;
		}
			
		case kIOMessageSystemHasPoweredOn:
		{
			PGTS_BEGIN_WAKE_PREPARATION ();
			NSString* note = kPGTSConnectionMonitorAwakeNotification;
			[[NSNotificationCenter defaultCenter] postNotificationName: note object: monitor];
			PGTS_END_WAKE_PREPARATION ();
			break;
		}
			
        default:
            break;
    }

}


- (id) init
{
	if ((self = [super init]))
	{
		atexit (&ProcessWillExit);

		io_object_t ioNotifier = 0;
		IONotificationPortRef ioNotificationPort = NULL;
		mIOPowerSession = IORegisterForSystemPower (self, &ioNotificationPort, &WorkspaceWillSleep, &ioNotifier);
		if (mIOPowerSession)
		{
			CFRunLoopRef rl = CFRunLoopGetCurrent ();
			CFRunLoopAddSource (rl, IONotificationPortGetRunLoopSource (ioNotificationPort), (CFStringRef) kCFRunLoopCommonModes);
		}
		else
		{
			BXLogError (@"Failed to register for system sleep.");
		}
	}
	return self;
}

- (void) monitorConnection: (PGTSConnection *) connection
{
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver: connection selector: @selector (applicationWillTerminate:) name: kPGTSConnectionMonitorExitNotification object: self];
	[nc addObserver: connection selector: @selector (workspaceWillSleep:) name: kPGTSConnectionMonitorSleepNotification object: self];
	[nc addObserver: connection selector: @selector (workspaceDidWake:) name: kPGTSConnectionMonitorAwakeNotification object: self];
}

- (void) unmonitorConnection: (PGTSConnection *) connection
{
	NSString* notificationNames [] = {
		kPGTSConnectionMonitorExitNotification, 
		kPGTSConnectionMonitorSleepNotification, 
		kPGTSConnectionMonitorAwakeNotification,
	};
	
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	for (int i = 0, count = BXArraySize (notificationNames); i < count; i++)
		[nc removeObserver: connection name: notificationNames [i] object: self];
}

- (io_connect_t) IOPowerSession;
{
	return mIOPowerSession;
}
@end


@implementation PGTSAppKitConnectionMonitor
- (void) monitorConnection: (PGTSConnection *) connection
{
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver: connection selector: @selector (applicationWillTerminate:)
			   name: NSApplicationWillTerminateNotification object: NSApp];
	
	nc = [[NSWorkspace sharedWorkspace] notificationCenter];
	[nc addObserver: connection selector: @selector (workspaceWillSleep:) name: NSWorkspaceWillSleepNotification object: nil];
	[nc addObserver: connection selector: @selector (workspaceDidWake:) name: NSWorkspaceDidWakeNotification object: nil];
}

- (void) unmonitorConnection: (PGTSConnection *) connection
{
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver: connection name: NSApplicationWillTerminateNotification object: nil];
	
	nc = [[NSWorkspace sharedWorkspace] notificationCenter];
	[nc removeObserver: connection name: NSWorkspaceWillSleepNotification object: nil];
	[nc removeObserver: connection name: NSWorkspaceDidWakeNotification object: nil];
}
@end
