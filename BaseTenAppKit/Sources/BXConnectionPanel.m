//
// BXConnectionPanel.m
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

#import "BXConnectionPanel.h"


static NSArray* gManuallyNotifiedKeys = nil;


@implementation BXConnectionPanel

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        gManuallyNotifiedKeys = [[NSArray alloc] initWithObjects: @"displayedAsSheet", nil];
    }
}

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *) aKey
{
    BOOL rval = NO;
    if (NO == [gManuallyNotifiedKeys containsObject: aKey])
        rval = [super automaticallyNotifiesObserversForKey: aKey];
    return rval;
}

+ (id) connectionPanel
{
	BXConnectionViewManager* manager = [[BXConnectionViewManager alloc] init];
	NSView* bonjourListView = [manager bonjourListView];
	NSRect contentRect = [bonjourListView frame];
	contentRect.origin = NSZeroPoint;
	BXConnectionPanel* panel = [[[self alloc] initWithContentRect: contentRect 
														styleMask: NSTitledWindowMask | NSResizableWindowMask 
														  backing: NSBackingStoreBuffered 
															defer: YES] autorelease];
	[panel setMinSize: contentRect.size];
	[panel setReleasedWhenClosed: YES];
	[panel setContentView: bonjourListView];
	[panel setConnectionViewManager: manager];
	[manager setDelegate: panel];
	
	[manager release];
	return panel;
}

- (void) dealloc
{
	[mViewManager release];
    [mAuxiliaryPanel release];
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
    [self willChangeValueForKey: @"displayedAsSheet"];
	if (nil == docWindow)
		mDisplayedAsSheet = NO;
	else
		mDisplayedAsSheet = YES;
    [self didChangeValueForKey: @"displayedAsSheet"];
	
	[mViewManager startDiscovery];
    [super beginSheetModalForWindow: docWindow modalDelegate: modalDelegate
                     didEndSelector: didEndSelector contextInfo: contextInfo];
}

- (void) auxiliarySheetDidEnd: (NSWindow *) sheet returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    mDisplayingAuxiliarySheet = NO;
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

- (void) setShowsOtherButton: (BOOL) aBool
{
	[mViewManager setShowsOtherButton: aBool];
}

- (void) setDatabaseName: (NSString *) aName
{
	[mViewManager setDatabaseName: aName];
}
@end


@implementation BXConnectionPanel (BXConnectionViewManagerDelegate)
- (void) BXShowByHostnameView: (NSView *) hostnameView
{
    NSRect contentRect = [hostnameView frame];
    contentRect.origin = NSZeroPoint;

	if (mDisplayedAsSheet)
	{		
        [self setContentView: nil];
		[self setFrame: contentRect display: YES animate: YES];
		[self setContentView: hostnameView];
        [hostnameView setNeedsDisplay: YES];
	}
	else
	{
        if (nil == mAuxiliaryPanel)
        {
            mAuxiliaryPanel = [[NSPanel alloc] initWithContentRect: contentRect 
                                                         styleMask: NSTitledWindowMask | NSResizableWindowMask 
                                                           backing: NSBackingStoreBuffered defer: YES];

            [mAuxiliaryPanel setReleasedWhenClosed: NO];
            [mAuxiliaryPanel setFrame: contentRect display: NO];
            [mAuxiliaryPanel setContentView: hostnameView];
        }        
        
		[NSApp beginSheet: mAuxiliaryPanel modalForWindow: self modalDelegate: self 
           didEndSelector: @selector (auxiliarySheetDidEnd:returnCode:contextInfo:) 
              contextInfo: NULL];
        mDisplayingAuxiliarySheet = YES;
	}
}

- (void) BXShowBonjourListView: (NSView *) bonjourListView
{
    NSRect contentRect = [bonjourListView frame];
    contentRect.origin = NSZeroPoint;
    
    [self setContentView: nil];
    [self setFrame: contentRect display: YES animate: YES];
    [self setContentView: bonjourListView];
    [bonjourListView setNeedsDisplay: YES];
}

- (void) BXHandleError: (NSError *) error
{
    [[NSAlert alertWithError: error] beginSheetModalForWindow: nil
                                                modalDelegate: nil 
                                               didEndSelector: NULL
                                                  contextInfo: NULL];
}

- (void) BXBeginConnecting
{
    if (YES == mDisplayingAuxiliarySheet)
    {
        [NSApp endSheet: mAuxiliaryPanel];
        [mAuxiliaryPanel close];
    }
	
	[NSApp endSheet: self returnCode: NSOKButton];
	[[self retain] autorelease];
	[self close];
}

- (void) BXCancelConnecting
{
    if (YES == mDisplayingAuxiliarySheet)
	{
		[NSApp endSheet: mAuxiliaryPanel];
		[mAuxiliaryPanel close];
	}
	else
	{
		[NSApp endSheet: self returnCode: NSCancelButton];
		[[self retain] autorelease];
		[self close];
	}
}
@end