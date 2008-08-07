//
// BXNetServiceConnector.m
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

#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXLogger.h>
#import "BXNetServiceConnector.h"
#import "BXConnectionPanel.h"
#import "BXAuthenticationPanel.h"
#import "BXDatabaseContextAdditions.h"


/**
 * A connection setup manager for use with Bonjour.
 * Determines connection information from the database URI
 * and then presents dialogs for the missing information.
 * \note Presently one is created automatically in BXDatabaseContext::connect:.
 * \ingroup baseten_appkit
 */
@implementation BXNetServiceConnector 

- (void) dealloc
{
	[[databaseContext notificationCenter] removeObserver: self];
	[mAuthenticationPanel release];
    [mPanel release];
	[super dealloc];
}

- (void) finalize
{
	[mPanel end];
	[mAuthenticationPanel end];
	[super finalize];
}

- (void) awakeFromNib
{
    [self setDatabaseContext: databaseContext];
}

- (IBAction) connect: (id) sender
{	
    [databaseContext setUsesKeychain: YES];
	if (nil != [[databaseContext databaseURI] host])
	{
		[self continueFromDatabaseSelection: nil returnCode: NSOKButton];
	}
	else
	{
		BXConnectionPanel* panel = [BXConnectionPanel connectionPanel];
		[self setPanel: panel];
		
		[panel setLeftOpenOnContinue: YES];
		[panel setReleasedWhenClosed: NO];
		[panel setDatabaseContext: databaseContext];
		
		if (nil == modalWindow)
		{
			SEL selector = @selector (connectionPanelDidEnd:returnCode:contextInfo:);
			NSMethodSignature* signature = [self methodSignatureForSelector: selector];
			
			NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: signature];
			[invocation setTarget: self];
			[invocation setSelector: selector];
			
			[panel setDidEndInvocation: invocation];
			[panel makeKeyAndOrderFront: nil];
		}
		else
		{
			[panel beginSheetModalForWindow: modalWindow modalDelegate: self 
							 didEndSelector: @selector (connectionPanelDidEnd:returnCode:contextInfo:) 
								contextInfo: NULL];
		}
	}
}

- (void) connectionPanelDidEnd: (BXConnectionPanel *) panel returnCode: (int) returnCode 
				   contextInfo: (void *) contextInfo
{
	[[databaseContext internalDelegate] databaseContextGotDatabaseURI: databaseContext];
	[self continueFromDatabaseSelection: panel returnCode: returnCode];
}

- (void) continueFromDatabaseSelection: (BXConnectionPanel *) panel returnCode: (int) returnCode
{
	if (NSOKButton == returnCode)
	{
        if (NO == [databaseContext usesKeychain] || 
            NO == [databaseContext fetchPasswordFromKeychain])
        {
            [panel end];
            [self displayAuthenticationPanel];
        }
        else
        {
            [databaseContext setConnectionSetupManager: self];
            [databaseContext connectAsync];
        }
    }
    else
    {
		[databaseContext disconnect];
		[databaseContext BXConnectionSetupManagerFinishedAttempt];
        [panel end];
    }
}

- (void) displayAuthenticationPanel
{
    if (nil == mAuthenticationPanel)
        [self setAuthenticationPanel: [BXAuthenticationPanel authenticationPanel]];
    
    [self setPanel: mAuthenticationPanel];

	[mAuthenticationPanel setDatabaseContext: databaseContext];
    [mAuthenticationPanel setLeftOpenOnContinue: YES];
        
	[mAuthenticationPanel beginSheetModalForWindow: modalWindow modalDelegate: self
									didEndSelector: @selector (authenticationPanelDidEnd:returnCode:contextInfo:)
									   contextInfo: NULL];
}

- (void) authenticationPanelDidEnd: (NSWindow *) panel returnCode: (int) returnCode
					   contextInfo: (void *) contextInfo
{
	if (NSOKButton == returnCode)
	{
		BXAssertVoidReturn (nil != databaseContext, @"Expected databaseContext not to be nil.");
		[databaseContext setConnectionSetupManager: self];
		[databaseContext connectAsync];
	}
    else
    {
        [mAuthenticationPanel end];
        [self setAuthenticationPanel: nil];
		[databaseContext disconnect];
		[databaseContext BXConnectionSetupManagerFinishedAttempt];
    }
}

- (void) BXDatabaseContext: (BXDatabaseContext *) context displayPanelForTrust: (SecTrustRef) trust
{
    [mPanel end];
    [self setPanel: nil];

	[context displayPanelForTrust: trust modalWindow: modalWindow];
}

- (void) endConnecting: (NSNotification *) notification
{    
	NSDictionary* userInfo = [notification userInfo];
	NSError* error = [userInfo objectForKey: kBXErrorKey];
	if (nil != error)
    {
        if ([[error domain] isEqualToString: kBXErrorDomain] &&
            kBXErrorAuthenticationFailed == [error code])
        {
            if (mPanel != mAuthenticationPanel && [mPanel isVisible])
            {
                [mPanel end];
                [self setPanel: nil];
            }
			if (NO == [mAuthenticationPanel isVisible])
				[self displayAuthenticationPanel];
            
            [mAuthenticationPanel setAuthenticating: NO];
            //FIXME: localization
            [mAuthenticationPanel setMessage: @"Authentication failed"];            
        }
        else
        {
            [mPanel end];
            [self setPanel: nil];
            [self setAuthenticationPanel: nil];
            
            NSAlert* alert = [NSAlert alertWithError: error];
            [alert beginSheetModalForWindow: nil modalDelegate: self 
							 didEndSelector: @selector (connectionSetupAlertDidEnd:returnCode:contextInfo:) 
								contextInfo: NULL];
			[databaseContext BXConnectionSetupManagerFinishedAttempt];
        }
    }
    else
    {        
        [mPanel end];
        [self setPanel: nil];
    }
}

- (void) connectionSetupAlertDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
	//FIXME: userinfo?
	NSNotification* notification = [NSNotification notificationWithName: kBXConnectionSetupAlertDidEndNotification object: databaseContext];
	[[databaseContext internalDelegate] databaseContextConnectionFailureAlertDismissed: databaseContext];
	[[databaseContext notificationCenter] postNotification: notification];
}

- (void) setDatabaseContext: (BXDatabaseContext *) aContext
{
    NSNotificationCenter* nc = nil;
    
    if (nil != databaseContext)
    {
        nc = [databaseContext notificationCenter];
        [nc removeObserver: self name: kBXConnectionFailedNotification object: databaseContext];
        [nc removeObserver: self name: kBXConnectionSuccessfulNotification object: databaseContext];
    }
    
    if (nil != aContext)
    {
		databaseContext = aContext;
        nc = [databaseContext notificationCenter];
        [nc addObserver: self selector: @selector (endConnecting:) 
                   name: kBXConnectionFailedNotification object: databaseContext];
        [nc addObserver: self selector: @selector (endConnecting:) 
                   name: kBXConnectionSuccessfulNotification object: databaseContext];    
    }
}

- (void) setPanel: (BXPanel *) aPanel
{
    if (mPanel != aPanel)
    {
        [mPanel autorelease];
        mPanel = [aPanel retain];
    }
}

- (void) setAuthenticationPanel: (BXAuthenticationPanel *) aPanel
{
    if (mAuthenticationPanel != aPanel)
    {
        [mAuthenticationPanel release];
        mAuthenticationPanel = [aPanel retain];
    }
}

- (void) setModalWindow: (NSWindow *) aWindow
{
	modalWindow = aWindow;
}

@end
