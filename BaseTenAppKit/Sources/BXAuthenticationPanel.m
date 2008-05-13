//
// BXAuthenticationPanel.m
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
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

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXDatabaseAdditions.h>
#import "BXAuthenticationPanel.h"


static NSNib* gAuthenticationViewNib = nil;
static NSArray* gManuallyNotifiedKeys = nil;

const float kSizeDiff = 25.0;


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
        gManuallyNotifiedKeys = [[NSArray alloc] initWithObjects: @"isAuthenticating", @"username", nil];
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
	return [[[self alloc] initWithContentRect: NSZeroRect styleMask: NSTitledWindowMask
									  backing: NSBackingStoreBuffered defer: YES] autorelease];
}

- (id) initWithContentRect: (NSRect) contentRect styleMask: (unsigned int) styleMask
                   backing: (NSBackingStoreType) bufferingType defer: (BOOL) deferCreation
{
    if ((self = [super initWithContentRect: contentRect styleMask: styleMask 
                                   backing: bufferingType defer: deferCreation]))
    {
        [gAuthenticationViewNib instantiateNibWithOwner: self topLevelObjects: NULL];
		NSSize contentSize = [mPasswordAuthenticationView frame].size;
        contentSize.height -= kSizeDiff;
		[self setContentSize: contentSize];
		[self setContentView: mPasswordAuthenticationView];
    }
    return self;
}

- (void) dealloc
{
    [mPasswordAuthenticationView release];
	[mDatabaseContext release];
	[mUsername release];
    [super dealloc];
}

- (void) beginSheetModalForWindow: (NSWindow *) docWindow modalDelegate: (id) modalDelegate 
				   didEndSelector: (SEL) didEndSelector contextInfo: (void *) contextInfo
{
	NSURL* connectionURI = [mDatabaseContext databaseURI];
	[self setUsername: [connectionURI user]];
	[mPasswordField setObjectValue: [connectionURI password]];
	[super beginSheetModalForWindow: docWindow modalDelegate: modalDelegate
					 didEndSelector: didEndSelector contextInfo: contextInfo];
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

- (NSString *) username
{
	NSString* rval = mUsername;
	if (0 == [rval length])
		rval = nil;
	return rval;
}

- (void) setUsername: (NSString *) aString
{
	if (mUsername != aString && ![mUsername isEqualToString: aString])
	{
		[self willChangeValueForKey: @"username"];
		[mUsername release];
		mUsername = [aString retain];
		[self didChangeValueForKey: @"username"];
	}
}

- (void) setMessage: (NSString *) aString
{
    id oldValue = [mMessageTextField objectValue];
    if (nil != oldValue && 0 == [oldValue length])
        oldValue = nil;

    BOOL change = NO;
    NSRect frame = [self frame];
    if (nil == oldValue && nil != aString)
    {
        frame.origin.y -= kSizeDiff;
        frame.size.height += kSizeDiff;
        change = YES;
    }
    else if (nil != oldValue && nil == aString)
    {
        frame.origin.y += kSizeDiff;
        frame.size.height -= kSizeDiff;
        change = YES;
    }
    
    if (change)
	{
		BOOL isVisible = [self isVisible];
        [self setFrame: frame display: isVisible animate: isVisible];
	}
    
	[mMessageTextField setObjectValue: aString];
    [self makeFirstResponder: mCredentialFieldMatrix];
}

- (void) end
{
	[super end];
	[self setAuthenticating: NO];
}
@end


@implementation BXAuthenticationPanel (IBActions)
- (IBAction) authenticate: (id) sender
{
	[self makeFirstResponder: self];
	
	NSURL* connectionURI = [mDatabaseContext databaseURI];
	connectionURI = [connectionURI BXURIForHost: nil database: nil 
									   username: [mUsernameField objectValue]
									   password: [mPasswordField objectValue]];
	[mDatabaseContext setDatabaseURIInternal: connectionURI];
	if (NSOnState == [mRememberInKeychainButton state])
    {
        //This should be done before -[BXDatabaseContext connect] since SecKeychainUnlock might get called.
        [[NSRunLoop currentRunLoop] performSelector: @selector (storeURICredentials)
                                             target: mDatabaseContext
                                           argument: nil
                                              order: UINT_MAX
                                              modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
    }
	
	[self setAuthenticating: YES];
    [self continueWithReturnCode: NSOKButton];
}

- (IBAction) cancelAuthentication: (id) sender
{
	[self setAuthenticating: NO];
    [self continueWithReturnCode: NSCancelButton];
}
@end
