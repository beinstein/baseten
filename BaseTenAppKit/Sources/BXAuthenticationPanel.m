//
// BXAuthenticationPanel.m
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

#import <BaseTen/BaseTen.h>
#import "BXAuthenticationPanel.h"


__strong static NSNib* gAuthenticationViewNib = nil;
__strong static NSString* kNSKVOContext = @"kBXAuthenticationPanelNSKVOContext";
static const CGFloat kSizeDiff = 25.0;



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
    }
}


+ (id) authenticationPanel
{
	return [[[self alloc] initWithContentRect: NSZeroRect styleMask: NSTitledWindowMask
									  backing: NSBackingStoreBuffered defer: YES] autorelease];
}


- (id) initWithContentRect: (NSRect) contentRect styleMask: (NSUInteger) styleMask
                   backing: (NSBackingStoreType) bufferingType defer: (BOOL) deferCreation
{
    if ((self = [super initWithContentRect: contentRect styleMask: styleMask 
                                   backing: bufferingType defer: deferCreation]))
    {
        [gAuthenticationViewNib instantiateNibWithOwner: self topLevelObjects: NULL];
		
		NSRect contentFrame = [mPasswordAuthenticationView frame];
        contentFrame.size.height -= kSizeDiff;
		NSRect windowFrame = [self frameRectForContentRect: contentFrame];
		[self setFrame: windowFrame display: NO];
		[self setMinSize: windowFrame.size];
		
		[self setContentView: mPasswordAuthenticationView];
		[mPasswordAuthenticationView setAutoresizingMask:
		 NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable |
		 NSViewMinYMargin | NSViewMaxYMargin | NSViewHeightSizable];

		[self addObserver: self forKeyPath: @"message" 
				  options: NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew 
				  context: kNSKVOContext];
    }
    return self;
}


- (void) dealloc
{
    [mPasswordAuthenticationView release];
	[mUsernameField release];
	[mPasswordField release];
	[mRememberInKeychainButton release];
	[mMessageTextField release];
	[mCredentialFieldMatrix release];
	[mProgressIndicator release];
	
	[mUsername release];
	[mPassword release];
	[mMessage release];
    [super dealloc];
}


- (id <BXAuthenticationPanelDelegate>) delegate
{
	return mDelegate;
}


- (void) setDelegate: (id <BXAuthenticationPanelDelegate>) object
{
	mDelegate = object;
}


- (BOOL) isAuthenticating
{
    return mIsAuthenticating;
}


- (void) setAuthenticating: (BOOL) aBool
{
	mIsAuthenticating = aBool;
}


- (BOOL) shouldStorePasswordInKeychain
{
	return mShouldStorePasswordInKeychain;
}


- (void) setShouldStorePasswordInKeychain: (BOOL) aBool
{
	mShouldStorePasswordInKeychain = aBool;
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


- (NSString *) message
{
	NSString* retval = mMessage;
	if (0 == [retval length])
		retval = nil;
	return retval;
}


- (NSString *) address
{
	NSString *retval = mAddress;
	if (0 == [retval length])
		retval = nil;
	return retval;
}


- (void) setUsername: (NSString *) aString
{
	if (mUsername != aString)
	{
		[mUsername release];
		mUsername = [aString retain];
	}
}


- (void) setPassword: (NSString *) aString
{
	if (mPassword != aString)
	{
		[mPassword release];
		mPassword = [aString retain];
	}
}


- (void) setMessage: (NSString *) aString
{
	if (mMessage != aString)
	{
		[mMessage release];
		mMessage = [aString retain];
	}
}


- (void) setAddress: (NSString *) aString
{
	if (mAddress != aString)
	{
		[mAddress release];
		mAddress = [aString retain];
	}
}


- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary *) change context: (void *) context
{
    if (kNSKVOContext == context) 
	{
		BOOL isVisible = [self isVisible];
		NSRect frame = [self frame];
		id oldMessage = [change objectForKey: NSKeyValueChangeOldKey];
		id newMessage = [change objectForKey: NSKeyValueChangeNewKey];
		if ([NSNull null] == oldMessage)
			oldMessage = nil;
		if ([NSNull null] == newMessage)
			newMessage = nil;
				
		if (![oldMessage length] && [newMessage length])
		{
			frame.size.height += kSizeDiff;
			frame.origin.y -= kSizeDiff;
		}
		else if ([oldMessage length] && ![newMessage length])
		{
			frame.size.height -= kSizeDiff;
			frame.origin.y += kSizeDiff;
		}
		
		[self setFrame: frame display: isVisible animate: isVisible];
	}
	else 
	{
		[super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
	}
}
@end



@implementation BXAuthenticationPanel (IBActions)
- (IBAction) authenticate: (id) sender
{
	[mDelegate authenticationPanel: self gotUsername: mUsername password: mPassword];
	[self setAuthenticating: YES];
	[self setPassword: nil];
}


- (void) cancelAuthentication2
{
	if (mIsAuthenticating)
	{
		[mDelegate authenticationPanelCancel: self];
		[self setAuthenticating: NO];
	}
	else
	{
		[mDelegate authenticationPanelEndPanel: self];
	}
}


- (IBAction) cancelAuthentication: (id) sender
{
	//This is required, if we don't want the cancel button to stay highlighted.
	//Tested with NSButtons as well as a matrix of NSButtonCells.
	NSRunLoop* rl = [NSRunLoop currentRunLoop];
	NSArray* modes = [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil];
	[rl performSelector: @selector (cancelAuthentication2) target: self argument: nil order: NSUIntegerMax modes: modes];
}
@end
