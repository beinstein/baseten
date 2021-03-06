//
// BXConnectionViewController.m
// BaseTen
//
// Copyright (C) 2009 Marko Karppinen & Co. LLC.
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

#import "BXConnectionViewController.h"


@implementation BXConnectionViewController
+ (NSNib *) nibInstance
{
	[NSException raise: NSInternalInconsistencyException format: @"This is an abstract class."];
	return nil;
}

- (id) init
{
	if ((self = [super init]) && [[[self class] nibInstance] instantiateNibWithOwner: self topLevelObjects: NULL])
	{
		mViewSize = [mView frame].size;
	}
	return self;
}

- (void) dealloc
{
	[mView release];
	[mOtherButton release];
	[mCancelButton release];
	[mConnectButton release];
	[mProgressIndicator release];
	[super dealloc];
}

- (NSView *) view
{
	return mView;
}

- (NSSize) viewSize
{
	return mViewSize;
}

- (NSResponder *) initialFirstResponder
{
	return mInitialFirstResponder;
}

- (NSString *) host
{
	return nil;
}

- (NSInteger) port
{
	return -1;
}

- (void) setCanCancel: (BOOL) aBool
{
	mCanCancel = aBool;
}

- (void) setConnecting: (BOOL) aBool
{
	mConnecting = aBool;
}

- (BOOL) isConnecting
{
	return mConnecting;
}

- (BOOL) canCancel
{
	return mCanCancel;
}

- (void) setDelegate: (id <BXConnectionViewControllerDelegate>) object
{
	mDelegate = object;
}

- (IBAction) otherButtonClicked: (id) sender
{
	[mDelegate connectionViewControllerOtherButtonClicked: self];
}

- (IBAction) cancelButtonClicked: (id) sender
{
	[mDelegate connectionViewControllerCancelButtonClicked: self];
}

- (IBAction) connectButtonClicked: (id) sender
{
	[mDelegate connectionViewControllerConnectButtonClicked: self];
}
@end
