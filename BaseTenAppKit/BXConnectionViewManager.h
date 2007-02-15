//
// BXConnectionViewManager.h
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

#import <Cocoa/Cocoa.h>


@protocol BXConnectionViewManagerDelegate
- (void) BXShowHostnameView: (NSView *) aView;
- (void) BXShowBonjourListView: (NSView *) aView;
@end


@interface BXConnectionViewManager : NSObject 
{
	IBOutlet NSView*				mBonjourListView;
	IBOutlet NSView*				mHostnameView;
	
	IBOutlet NSArrayController*		mBonjourArrayController;
	
	IBOutlet NSButton*				mRememberPasswordButton;
	IBOutlet NSTextFieldCell*		mUsernameField;
	IBOutlet NSTextFieldCell*		mPasswordField;
	
	IBOutlet NSProgressIndicator*	mBonjourListProgressIndicator;
	IBOutlet NSProgressIndicator*	mByHostnameProgressIndicator;
	
	NSNetServiceBrowser*	mNetServiceBrowser;
	BXDatabaseContext*		mDatabaseContext;
	
	BOOL					mShowsOtherButton;
	BOOL					mIsConnecting;
}

- (BOOL) canConnect;
- (BOOL) isConnecting;
- (BOOL) showsOtherButton;
- (void) setShowsOtherButton: (BOOL) aBool;

- (IBAction) connect: (id) sender;
- (IBAction) cancelConnecting: (id) sender;
- (IBAction) login: (id) sender;
- (IBAction) cancelLogin: (id) sender;
- (IBAction) showBonjourList: (id) sender;
- (IBAction) showHostnameView: (id) sender;

- (void) startDiscovery;
- (void) setDatabaseContext: (BXDatabaseContext *) ctx;
- (BXDatabaseContext *) databaseContext;

- (NSView *) bonjourListView;

@end
