//
// BXDatabaseContextAdditions.m
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
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

#import "BXDatabaseContextAdditions.h"
#import "BXNetServiceConnector.h"
#import <Cocoa/Cocoa.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXDelegateProxy.h>
#import <BaseTen/BXInterface.h>
#import <SecurityInterface/SFCertificateTrustPanel.h>


@implementation BXDatabaseContext (BaseTenAppKitAdditions)

- (void) awakeFromNib
{
	[(BXDelegateProxy *) mDelegateProxy setDelegateForBXDelegateProxy: delegate];
	
	if (mConnectsOnAwake)
	{
		[modalWindow makeKeyAndOrderFront: nil];
		[[NSRunLoop currentRunLoop] performSelector: @selector (connect:)
											 target: self 
										   argument: nil
											  order: UINT_MAX
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	}
}

- (void) displayPanelForTrust: (SecTrustRef) trust
{
	[self displayPanelForTrust: (SecTrustRef) trust modalWindow: modalWindow];
}

- (void) displayPanelForTrust: (SecTrustRef) trust modalWindow: (NSWindow *) aWindow
{
	mDisplayingSheet = YES;
	SFCertificateTrustPanel* panel = [SFCertificateTrustPanel sharedCertificateTrustPanel];
	NSBundle* appKitBundle = [NSBundle bundleWithPath: @"/System/Library/Frameworks/AppKit.framework"];
	[panel setAlternateButtonTitle: [appKitBundle localizedStringForKey: @"Cancel" value: @"Cancel" table: @"Common"]];
	
	if (aWindow)
	{
		[panel beginSheetForWindow: aWindow modalDelegate: self 
					didEndSelector: @selector (certificateTrustSheetDidEnd:returnCode:contextInfo:)
					   contextInfo: trust trust: trust message: nil];
	}
	else
	{
		NSInteger status = [panel runModalForTrust: trust message: nil];
		[self certificateTrustSheetDidEnd: nil returnCode: status contextInfo: trust];
	}
}

- (void) certificateTrustSheetDidEnd: (NSWindow *) sheet returnCode: (int) returnCode contextInfo: (void *) trust
{
	mDisplayingSheet = NO;
	BOOL accepted = (NSFileHandlingPanelOKButton == returnCode);
	[mDatabaseInterface handledTrust: (SecTrustRef) trust accepted: accepted];
	
	if (accepted)
		[self connectAsync];
	else
	{
		[self setCanConnect: YES];
		
		//FIXME: Create an NSError and set it in userInfo to kBXErrorKey.
		NSNotification* notification = [NSNotification notificationWithName: kBXConnectionFailedNotification object: self userInfo: nil];
		[mDelegateProxy databaseContext: self failedToConnect: nil];
		[[self notificationCenter] postNotification: notification];
	}
}

- (id <BXConnector>) copyDefaultConnectionSetupManager
{
	return [[BXNetServiceConnector alloc] init];
}

@end
