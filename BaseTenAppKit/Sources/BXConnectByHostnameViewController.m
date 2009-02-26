//
// BXConnectByHostnameViewController.m
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


#import "BXConnectByHostnameViewController.h"


@implementation BXConnectByHostnameViewController
__strong static NSNib* gNib = nil;

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (! tooLate)
	{
		tooLate = YES;
		gNib = [[NSNib alloc] initWithNibNamed: @"ConnectByHostnameView" bundle: [NSBundle bundleForClass: self]];
	}
}

+ (NSNib *) nibInstance
{
	return gNib;
}

- (void) dealloc
{
	[mAddress release];
	[super dealloc];
}

- (NSString *) host
{
	return mAddress;
}

- (void) setHost: (NSString *) string
{
	if (mAddress != string)
	{
		[mAddress release];
		mAddress = [string retain];
	}
}
@end
