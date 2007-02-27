//
// BXNetServiceConnector.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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

#import "BXNetServiceConnector.h"
#import "BXConnectionPanel.h"
#import "BXAuthenticationPanel.h"
#import "BXDatabaseContextAdditions.h"


@implementation BXNetServiceConnector 

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (IBAction) connect: (id) sender
{	
	BXConnectionPanel* panel = [BXConnectionPanel connectionPanel];
	[panel retain];
	[panel setReleasedWhenClosed: YES];
	[panel setDatabaseContext: databaseContext];
	[panel beginSheetModalForWindow: modalWindow modalDelegate: self 
					 didEndSelector: @selector (connectionPanelDidEnd:returnCode:contextInfo:) 
						contextInfo: NULL];
}

- (void) connectionPanelDidEnd: (NSWindow *) panel returnCode: (int) returnCode 
				   contextInfo: (void *) contextInfo
{
	if (NSOKButton == returnCode)
	{
		[[NSRunLoop currentRunLoop] performSelector: @selector (displayAuthenticationPanel)
											 target: self
										   argument: nil
											  order: UINT_MAX
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	}

}

- (void) displayAuthenticationPanel
{
	BXAuthenticationPanel* panel = [BXAuthenticationPanel authenticationPanel];
	[panel retain];
	[panel setReleasedWhenClosed: YES];
	[panel setDatabaseContext: databaseContext];
	[panel beginSheetModalForWindow: modalWindow modalDelegate: self
					 didEndSelector: @selector (authenticationPanelDidEnd:returnCode:contextInfo:)
						contextInfo: NULL];
}

- (void) authenticationPanelDidEnd: (NSWindow *) panel returnCode: (int) returnCode
					   contextInfo: (void *) contextInfo
{
	if (NSOKButton == returnCode)
	{
		NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
		[nc addObserver: self selector: @selector (endConnecting:) 
				   name: kBXConnectionFailedNotification object: databaseContext];
		[nc addObserver: self selector: @selector (endConnecting:) 
				   name: kBXConnectionSuccessfulNotification object: databaseContext];
		
		[databaseContext setConnectionSetupManager: self];
		[databaseContext connect];
	}
}

- (void) BXDatabaseContext: (BXDatabaseContext *) context displayPanelForTrust: (SecTrustRef) trust
{
	[context displayPanelForTrust: trust modalWindow: modalWindow];
}

- (void) endConnecting: (NSNotification *) notification
{
	NSDictionary* userInfo = [notification userInfo];
	NSError* error = [userInfo objectForKey: kBXErrorKey];
	if (nil != error)
	{
		NSAlert* alert = [NSAlert alertWithError: error];
		[alert beginSheetModalForWindow: modalWindow modalDelegate: nil didEndSelector: NULL contextInfo: NULL];
	}
}

@end
