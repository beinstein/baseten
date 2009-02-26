//
// BXAuthenticationPanel.h
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

#import <Cocoa/Cocoa.h>
#import <BaseTenAppKit/BXPanel.h>

@class BXDatabaseContext;


@protocol BXAuthenticationPanelDelegate <NSObject>
- (void) authenticationPanelCancel: (id) panel;
- (void) authenticationPanelEndPanel: (id) panel;
- (void) authenticationPanel: (id) panel gotUsername: (NSString *) username password: (NSString *) password;
@end


@interface BXAuthenticationPanel : BXPanel 
{	
	//Retained
	NSString*							mUsername;
	NSString*							mPassword;
	NSString*							mMessage;
	
    //Top-level objects
    IBOutlet NSView*                	mPasswordAuthenticationView;
    
    IBOutlet NSTextFieldCell*       	mUsernameField;
    IBOutlet NSSecureTextFieldCell*		mPasswordField;
    IBOutlet NSButton*              	mRememberInKeychainButton;
	IBOutlet NSTextField*				mMessageTextField;
    IBOutlet NSMatrix*              	mCredentialFieldMatrix;
	IBOutlet NSProgressIndicator*		mProgressIndicator;

	id <BXAuthenticationPanelDelegate>	mDelegate;

    BOOL                            	mIsAuthenticating;
	BOOL								mShouldStorePasswordInKeychain;
	BOOL								mMessageFieldHasContent;
}

+ (id) authenticationPanel;

- (BOOL) shouldStorePasswordInKeychain;
- (void) setShouldStorePasswordInKeychain: (BOOL) aBool;
- (NSString *) username;
- (void) setUsername: (NSString *) aString;
- (NSString *) password;
- (void) setPassword: (NSString *) aString;
- (void) setMessage: (NSString *) aString;
- (void) setAuthenticating: (BOOL) aBool;
- (void) setDelegate: (id <BXAuthenticationPanelDelegate>) object;
@end


@interface BXAuthenticationPanel (IBActions)
- (IBAction) authenticate: (id) sender;
- (IBAction) cancelAuthentication: (id) sender;
@end
