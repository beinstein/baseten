//
// BXConnectUsingBonjourViewController.m
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


#import "BXConnectUsingBonjourViewController.h"


@implementation BXConnectUsingBonjourViewController
__strong static NSNib* gNib = nil;

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (! tooLate)
	{
		tooLate = YES;
		gNib = [[NSNib alloc] initWithNibNamed: @"ConnectUsingBonjourView" bundle: [NSBundle bundleForClass: self]];
	}
}

+ (NSNib *) nibInstance
{
	return gNib;
}

- (void) dealloc
{
	[mAddressTable release];
	[mBonjourArrayController release];
	[mNetServiceBrowser release];
	[mNetServices release];
	[super dealloc];
}

- (NSString *) host
{
	return [[[mBonjourArrayController selectedObjects] lastObject] hostName];
}

- (NSInteger) port
{
	return [[[mBonjourArrayController selectedObjects] lastObject] port];
}

- (void) startDiscovery
{	
	if (! mDiscovering)
	{
		mDiscovering = YES;
		if (! mNetServiceBrowser)
		{
			mNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
			[mNetServiceBrowser setDelegate: self];
		}
		if (! mNetServices)
			mNetServices = [[NSMutableSet alloc] init];
		
		[mNetServiceBrowser searchForServicesOfType: @"_postgresql._tcp." inDomain: @""];
	}
}

- (void) stopDiscovery
{
	if (mDiscovering)
	{
		mDiscovering = NO;
		[mNetServiceBrowser stop];
		[mNetServices removeAllObjects];
	}
}
@end


@implementation BXConnectUsingBonjourViewController (NetServiceBrowserDelegate)
- (void) netServiceBrowser: (NSNetServiceBrowser *) netServiceBrowser 
			didFindService: (NSNetService *) netService moreComing: (BOOL) moreServicesComing
{
	if (! [mNetServices containsObject: netService])
	{
		[mNetServices addObject: netService];
		[netService resolveWithTimeout: 10.0];
		[netService setDelegate: self];
	}
}

- (void) netServiceDidResolveAddress: (NSNetService *) netService
{
	[mBonjourArrayController addObject: netService];
}

- (void) netService: (NSNetService *) netService didNotResolve: (NSDictionary *) errorDict
{
}
@end
