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
#import "BXAuthenticationPanel.h"


__strong static NSNib* gAuthenticationViewNib = nil;
__strong static NSArray* gManuallyNotifiedKeys = nil;

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
        gManuallyNotifiedKeys = [[NSArray alloc] initWithObjects: 
								 @"isAuthenticating", 
								 @"username", 
								 @"shouldStorePasswordInKeychain",
								 nil];
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
	[mUsername release];
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

- (BOOL) shouldStorePasswordInKeychain
{
	return mShouldStorePasswordInKeychain;
}

- (void) setShouldStorePasswordInKeychain: (BOOL) aBool
{
	if (aBool != mShouldStorePasswordInKeychain)
	{
		[self willChangeValueForKey: @"shouldStorePasswordInKeychain"];
		mShouldStorePasswordInKeychain = aBool;
		[self didChangeValueForKey: @"shouldStorePasswordInKeychain"];
	}
}

- (NSString *) username
{
	NSString* retval = mUsername;
	if (0 == [retval length])
		retval = nil;
	return retval;
}

- (NSString *) password
{
	NSString* retval = mPassword;
	if (0 == [retval length])
		retval = nil;
	return retval;
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

- (void) setPassword: (NSString *) aString
{
	if (mPassword != aString && ![mPassword isEqualToString: aString])
	{
		[self willChangeValueForKey: @"password"];
		[mPassword release];
		mPassword = [aString retain];
		[self didChangeValueForKey: @"password"];
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

	[self setAuthenticating: YES];
    [self continueWithReturnCode: NSOKButton];
	[self setPassword: nil];
}

- (IBAction) cancelAuthentication: (id) sender
{
	[self setAuthenticating: NO];
    [self continueWithReturnCode: NSCancelButton];
	[self setPassword: nil];
}
@end
