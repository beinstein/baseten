//
// BXAuthenticationPanel.m
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

#import "BXAuthenticationPanel.h"


static NSNib* gAuthenticationViewNib = nil;
static NSArray* gManuallyNotifiedKeys = nil;


@implementation BXAuthenticationPanel

+ (void) initialize
{
    [super initialize];
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        gAuthenticationViewNib = [[NSNib alloc] initWithNibNamed: @"AuthenticationView" 
                                                          bundle: [NSBundle bundleForClass: self]];
        gManuallyNotifiedKeys = [[NSArray alloc] initWithObjects: @"isAuthenticating", nil];
    }
}

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *) aKey
{
    BOOL rval = NO;
    if (NO == [gManuallyNotifiedKeys containsObject: aKey])
        rval = [super automaticallyNotifiesObserversForKey: aKey];
    return rval;
}

+ (id) authenticationPanel
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
        [gAuthenticationViewNib instantiateNibWithOwner: self topLevelObjects: NULL];
        [self setReleasedWhenClosed: YES];
		[self setContentView: mPasswordAuthenticationView];
		//FIXME: replace this with the actual size
		[self setContentSize: NSMakeSize (200.0, 200.0)];
    }
    return self;
}

- (void) dealloc
{
    [mPasswordAuthenticationView release];
	[mDatabaseContext release];
    [super dealloc];
}

- (BOOL) isAuthenticating
{
    return mIsAuthenticating;
}

- (void) setAuthenticating: (BOOL) aBool
{
	if (aBool != mIsAuthenticating)
	{
		[self willChangeValueForKey: @"isAuthenticating"];
		mIsAuthenticating = aBool;
		[self didChangeValueForKey: @"isAuthenticating"];		
	}
}

- (void) setDatabaseContext: (BXDatabaseContext *) ctx
{
	if (mDatabaseContext != ctx)
	{
		[mDatabaseContext release];
		mDatabaseContext = [ctx retain];
	}
}

- (BXDatabaseContext *) databaseContext
{
	return mDatabaseContext;
}

@end


@implementation BXAuthenticationPanel (IBActions)
- (IBAction) authenticate: (id) sender
{
	[self setAuthenticating: YES];
	[NSApp endSheet: self returnCode: NSOKButton];
    //Try to be cautious since we get released when closed.
    [[self retain] autorelease];
    [self close];
}

- (IBAction) cancelAuthentication: (id) sender
{
	[self setAuthenticating: NO];
    [NSApp endSheet: self returnCode: NSCancelButton];
    //Try to be cautious since we get released when closed.
    [[self retain] autorelease];
    [self close];
}
@end
