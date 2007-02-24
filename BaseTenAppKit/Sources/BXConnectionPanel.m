//
// BXConnectionPanel.m
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

#import "BXConnectionPanel.h"


@implementation BXConnectionPanel

+ (id) connectionPanel
{
	BXConnectionViewManager* manager = [[BXConnectionViewManager alloc] init];
	NSView* bonjourListView = [manager bonjourListView];
	NSRect contentRect = [mBonjourListView frame];
	contentRect.origin = NSZeroPoint;
	BXConnectionPanel* panel = [[[NSPanel alloc] initWithContentRect: contentRect 
														   styleMask: NSTitledWindowMask | NSResizableWindowMask 
															 backing: NSBackingStoreBuffered 
															   defer: YES] autorelease];
	[panel setReleasedWhenClosed: YES];
	[panel setContentView: bonjourListView];
	[panel setConnectionViewManager: manager];
	[manager setDelegate: self];
	
	[manager release];
	return panel;
}

- (void) dealloc
{
	[mViewManager release];
	[super dealloc];
}

- (void) setConnectionViewManager: (BXConnectionViewManager *) anObject
{
	if (mViewManager != anObject)
	{
		[mViewManager release];
		mViewManager = [anObject retain];
	}
}

- (void) beginSheetModalForWindow: (NSWindow *) docWindow modalDelegate: (id) modalDelegate 
				   didEndSelector: (SEL) didEndSelector contextInfo: (void *) contextInfo
{
	if (nil == docWindow)
		mDisplayedAsSheet = NO;
	else
		mDisplayedAsSheet = YES;
	
	mSheetDidEndSelector = didEndSelector;
	mSheetDelegate = modalDelegate;
	mSheetContextInfo = contextInfo;
	[NSApp beginSheet: self modalForWindow: docWindow modalDelegate: self 
	   didEndSelector: @selector (sheetDidEnd:returnCode:contextInfo:) 
		  contextInfo: NULL];
}

- (void) sheetDidEnd: (NSWindow *) sheet returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
	if (NULL != mSheetDidEndSelector)
	{
		NSMethodSignature* signature = [mSheetDelegate methodSignatureForSelector: mSheetDidEndSelector];
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: signature];
		[invocation setArgument: self atIndex: 2];
		[invocation setArgument: returnCode atIndex: 3];
		[invocation setArgument: mSheetContextInfo atIndex: 4];
		[invocation invoke];
	}
}

- (BOOL) displayedAsSheet
{
	return mDisplayedAsSheet;
}

- (void) setDatabaseContext: (BXDatabaseContext *) ctx
{
	[mViewManager setDatabaseContext: ctx];
}

- (BXDatabaseContext *) databaseContext
{
	return [mViewManager databaseContext];
}

- (void) BXShowHostnameView: (NSView *) hostnameView
{
}

- (void) BXShowBonjourListView: (NSView *) bonjourListView
{
}

@end
