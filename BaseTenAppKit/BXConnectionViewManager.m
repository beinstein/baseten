//
// BXConnectionViewManager.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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

#import "BXConnectionViewManager.h"
#import <BaseTen/BaseTen.h>


@implementation BXConnectionViewManager

- (BOOL) canConnect
{
	//FIXME: return some real value
	return YES;
}

- (BOOL) isConnecting
{
	return mIsConnecting;
}

- (BOOL) showsOtherButton
{
	return mShowsOtherButton;
}

- (void) setShowsOtherButton: (BOOL) aBool
{
	mShowsOtherButton = aBool;
}

- (void) sheetDidEnd: (NSWindow *) sheet returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
	//Just to make sure that there won't be any invalid pointers around.
	[mAuxiliaryPanel release];
	mAuxiliaryPanel = nil;
}

- (void) startDiscovery
{
	if (nil == mNetServiceBrowser)
	{
		mNetServiceBrowser = [[mNetServiceBrowser alloc] init];
		[mNetServiceBrowser setDelegate: self];
	}
	[mNetServiceBrowser searchForBrowsableDomains];
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[mNetServiceBrowser release];
	[mAuxiliaryPanel release];
	[mDatabaseContext release];
	[super dealloc];
}

- (void) setDatabaseContext: (BXDatabaseContext *) ctx
{
	if (mDatabaseContext != ctx)
	{
		NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
		[nc removeObserver: self name: kBXConnectionSuccessfulNotification object: mDatabaseContext];
		[nc removeObserver: self name: kBXConnectionFailedNotification object: mDatabaseContext];
		
		[mDatabaseContext release];
		mDatabaseContext = [ctx retain];
		
		[nc addObserver: self selector: @selector (endConnecting:) name: kBXConnectionSuccessfulNotification object: mDatabaseContext];
		[nc addObserver: self selector: @selector (endConnecting:) name: kBXConnectionFailedNotification object: mDatabaseContext];
	}
}

- (BXDatabaseContext *) databaseContext
{
	return mDatabaseContext;
}

- (NSView *) bonjourListView
{
	return mBonjourListView;
}

@end


@implementation BXConnectionViewManager (NetServiceBrowserDelegate)
- (void) netServiceBrowser: (NSNetServiceBrowser *) netServiceBrowser 
			 didFindDomain: (NSString *) domainName moreComing: (BOOL) moreDomainsComing
{
	[netServiceBrowser searchForServicesOfType: @"_postgresql._tcp" inDomain: domainName];
}

- (void) netServiceBrowser: (NSNetServiceBrowser *) netServiceBrowser 
			didFindService: (NSNetService *) netService moreComing: (BOOL) moreServicesComing
{
	[mBonjourArrayController addObject: netService];
}
@end


@implementation BXConnectionViewManager (IBActions)

- (IBAction) connect: (id) sender
{
	[mNetServiceBrowser stop];
	
	[self willChangeValueForKey: @"isConnecting"];
	mIsConnecting = YES;
	[self didChangeValueForKey: @"isConnecting"];
	
	if (nil != mAuxiliaryPanel)
	{
		[NSApp endSheet: mAuxiliaryPanel];
		[mAuxiliaryPanel close];
	}
		
	[mDatabaseContext connect];
}

- (IBAction) cancelConnecting: (id) sender
{
	[self willChangeValueForKey: @"isConnecting"];
	mIsConnecting = NO;
	[self didChangeValueForKey: @"isConnecting"];
	
	if (nil == mAuxiliaryPanel)
	{
		[NSApp endSheet: mPanel returnCode: NSCancelButton];
		[mPanel close];
	}
	else
	{
		[NSApp endSheet: mAuxiliaryPanel];
		[mAuxiliaryPanel close];
	}
}

- (IBAction) showBonjourList: (id) sender
{
	NSRect contentRect = [mBonjourListView frame];
	frame.origin = NSZeroPoint;
	
	[mPanel setContentView: mHostnameView];
	[mPanel setFrame: contentRect display: NO animate: YES];
}

- (IBAction) showHostnameView: (id) sender
{
	if ([mPanel displayedAsSheet])
	{
		NSRect contentRect = [mHostnameView frame];
		frame.origin = NSZeroPoint;
		
		[mPanel setContentView: mHostnameView];
		[mPanel setFrame: contentRect display: NO animate: YES];
	}
	else
	{
		mAuxiliaryPanel = [[NSPanel alloc] initWithContentRect: contentRect styleMask: NSTitledWindowMask | NSResizableWindowMask 
													   backing: NSBackingStoreBuffered defer: YES];
		[panel setContentView: mHostnameView];
		[NSApp beginSheet: mAuxiliaryPanel modalForWindow: self modalDelegate: self 
		   didEndSelector: @selector (sheetDidEnd:returnCode:contextInfo:)
			  contextInfo: NULL];
	}
}

@end