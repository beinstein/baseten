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
#import "BXAppKitAdditions.h"


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
	return [[[self alloc] initWithContentRect: NSZeroRect styleMask: NSTitledWindowMask | NSResizableWindowMask
									  backing: NSBackingStoreBuffered defer: YES] autorelease];
}

- (id) initWithContentRect: (NSRect) contentRect styleMask: (unsigned int) styleMask
                   backing: (NSBackingStoreType) bufferingType defer: (BOOL) deferCreation
{
    if ((self = [super initWithContentRect: contentRect styleMask: styleMask 
                                   backing: bufferingType defer: deferCreation]))
    {  
        mViewManager = [[BXConnectionViewManager alloc] init];
        [mViewManager setDelegate: self];
        [mViewManager setShowsOtherButton: YES];

        NSView* bonjourListView = [mViewManager bonjourListView];
        NSSize contentSize = [bonjourListView frame].size;
        
        mByHostnameViewMinSize = [[mViewManager byHostnameView] frame].size;
        mBonjourListViewMinSize = contentSize;

        [self setContentSize: contentSize];
        [self setContentView: bonjourListView];
        [self setMinSize: mBonjourListViewMinSize];

        [self setReleasedWhenClosed: YES];
        [self setDelegate: self];
    }
    return self;
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
    NSRect frame = [self frame];
    NSRect contentRect = [hostnameView frame];

	if (mDisplayedAsSheet)
	{		
        contentRect.origin = frame.origin;
        contentRect.origin.y -= contentRect.size.height - frame.size.height;
        contentRect.size.width = frame.size.width;
        
        [self setContentView: [NSView BXEmptyView]];
        [self display];
		[self setFrame: contentRect display: YES animate: YES];
		[self setContentView: hostnameView];
        [self setMinSize: mByHostnameViewMinSize];
        [hostnameView setNeedsDisplay: YES];
        
        mDisplayingByHostnameView = YES;
	}
	else
	{
        if (nil == mAuxiliaryPanel)
        {
            mAuxiliaryPanel = [[NSPanel alloc] initWithContentRect: contentRect 
                                                         styleMask: NSTitledWindowMask | NSResizableWindowMask 
                                                           backing: NSBackingStoreBuffered defer: YES];

            [mAuxiliaryPanel setReleasedWhenClosed: NO];
            [mAuxiliaryPanel setContentView: hostnameView];
            [mAuxiliaryPanel setDelegate: self];
        }        
        
		[NSApp beginSheet: mAuxiliaryPanel modalForWindow: self modalDelegate: self 
           didEndSelector: @selector (auxiliarySheetDidEnd:returnCode:contextInfo:) 
              contextInfo: NULL];
        mDisplayingAuxiliarySheet = YES;
	}
}

- (void) BXShowBonjourListView: (NSView *) bonjourListView
{
    NSRect frame = [self frame];
    NSRect contentRect = [bonjourListView frame];
    contentRect.origin = frame.origin;
    contentRect.origin.y -= contentRect.size.height - frame.size.height;
    contentRect.size.width = frame.size.width;

    [self setContentView: [NSView BXEmptyView]];
    [self display];
    [self setFrame: contentRect display: YES animate: YES];
    [self setContentView: bonjourListView];
    [self setMinSize: mBonjourListViewMinSize];
    [bonjourListView setNeedsDisplay: YES];

    mDisplayingByHostnameView = NO;
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

	[self continueWithReturnCode: NSOKButton];
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
        [self continueWithReturnCode: NSCancelButton];
	}
}

- (NSSize) windowWillResize: (NSWindow *) sender toSize: (NSSize) proposedFrameSize
{
    if (mDisplayingByHostnameView || sender != self)
    {
        NSSize size = [self frame].size;
        proposedFrameSize.height = size.height;
    }
    return proposedFrameSize;
}

@end