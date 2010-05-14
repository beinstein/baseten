//
// BXHostResolverTests.m
// BaseTen
//
// Copyright (C) 2010 Marko Karppinen & Co. LLC.
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

#import "BXHostResolverTests.h"
#import <BaseTen/BXHostResolver.h>
#import <OCMock/OCMock.h>


@implementation BXHostResolverTests
- (void) runResolverForNodename: (NSString *) nodename useDefaultRunLoopMode: (BOOL) useDefaultMode shouldFail: (BOOL) shouldFail
{
	BXHostResolver *resolver = [[BXHostResolver alloc] init];
	
	OCMockObject *mock = [OCMockObject mockForProtocol: @protocol (BXHostResolverDelegate)];
	// FIXME: use a HC matcher for addresses and error in the expected case.
	if (shouldFail)
	{
		[[mock expect] hostResolverDidFail: resolver error: OCMOCK_ANY];
		NSException *exc = [NSException exceptionWithName: NSInternalInconsistencyException
												   reason: @"Expected resolver to fail."
												 userInfo: nil];
		[[[mock stub] andThrow: exc] hostResolverDidSucceed: resolver addresses: OCMOCK_ANY];
	}
	else
	{
		[[mock expect] hostResolverDidSucceed: resolver addresses: OCMOCK_ANY];
		NSException *exc = [NSException exceptionWithName: NSInternalInconsistencyException 
												   reason: @"Expected resolver to succeed." 
												 userInfo: nil];
		[[[mock stub] andThrow: exc] hostResolverDidFail: resolver error: OCMOCK_ANY];
	}
	
	CFRunLoopRef runLoop = CFRunLoopGetCurrent ();
	
	[resolver setRunLoop: runLoop];
	[resolver setRunLoopMode: (id) (useDefaultMode ? kCFRunLoopDefaultMode : kCFRunLoopCommonModes)];
	[resolver setDelegate: (id <BXHostResolverDelegate>) mock];
	[resolver resolveHost: nodename];
	
	SInt32 status = CFRunLoopRunInMode (kCFRunLoopDefaultMode, 5.0, FALSE);
	status = 0;
	[mock verify];
}


- (void) test01
{
	[self runResolverForNodename: @"langley.macsinracks.net" useDefaultRunLoopMode: YES shouldFail: NO];
}


- (void) test02
{
	[self runResolverForNodename: @"langley.macsinracks.net" useDefaultRunLoopMode: NO shouldFail: NO];
}


- (void) test03
{
	[self runResolverForNodename: @"karppinen.fi" useDefaultRunLoopMode: YES shouldFail: NO];
}


- (void) test04
{
	[self runResolverForNodename: @"karppinen.fi" useDefaultRunLoopMode: NO shouldFail: NO];
}


- (void) test05
{
	[self runResolverForNodename: @"karppinen.invalid" useDefaultRunLoopMode: YES shouldFail: YES];
}


- (void) test06
{
	[self runResolverForNodename: @"karppinen.invalid" useDefaultRunLoopMode: NO shouldFail: YES];
}


- (void) test07
{
	[self runResolverForNodename: @"127.0.0.1" useDefaultRunLoopMode: YES shouldFail: NO];
}


- (void) test08
{
	[self runResolverForNodename: @"127.0.0.1" useDefaultRunLoopMode: NO shouldFail: NO];
}


- (void) test09
{
	[self runResolverForNodename: @"::1" useDefaultRunLoopMode: YES shouldFail: NO];
}


- (void) test10
{
	[self runResolverForNodename: @"::1" useDefaultRunLoopMode: YES shouldFail: NO];
}
@end
