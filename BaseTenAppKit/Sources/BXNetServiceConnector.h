//
// BXNetServiceConnector.h
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
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXConnectionSetupManagerProtocol.h>
#import <BaseTenAppKit/BXHostPanel.h>
#import <BaseTenAppKit/BXAuthenticationPanel.h>
@class BXAuthenticationPanel;
@class BXNetServiceConnector;
@class BXDatabaseContext;


enum BXNSConnectorCurrentPanel
{
	kBXNSConnectorNoPanel = 0,
	kBXNSConnectorHostPanel,
	kBXNSConnectorAuthenticationPanel
};


@protocol BXNSConnectorImplementation <NSObject>
- (void) beginConnectionAttempt;
- (void) endConnectionAttempt;
- (NSString *) runLoopMode;
- (void) presentError: (NSError *) error didEndSelector: (SEL) selector;
- (void) displayHostPanel: (BXHostPanel *) hostPanel;
- (void) endHostPanel: (BXHostPanel *) hostPanel;
- (void) displayAuthenticationPanel: (BXAuthenticationPanel *) authenticationPanel;
- (void) endAuthenticationPanel: (BXAuthenticationPanel *) authenticationPanel;
@end


@interface BXNSConnectorImplementation : NSObject
{
	BXNetServiceConnector* mConnector;
}
- (id) initWithConnector: (BXNetServiceConnector *) connector;
@end


@interface BXNetServiceConnector : NSObject <BXConnector, BXHostPanelDelegate, BXAuthenticationPanelDelegate>
{
	NSWindow* mModalWindow; //Weak
	BXDatabaseContext* mContext; //Weak
	BXNSConnectorImplementation <BXNSConnectorImplementation> *mConnectorImpl;
	
	BXHostPanel* mHostPanel;
	BXAuthenticationPanel* mAuthenticationPanel;
	enum BXNSConnectorCurrentPanel mCurrentPanel;
	
	CFHostRef mHost;
	NSString* mRunLoopMode;
	
	NSString* mHostName;
	NSInteger mPort;
}
- (void) checkHostReachability: (NSString *) name;
- (void) reachabilityCheckDidComplete: (const CFStreamError *) error;
- (NSWindow *) modalWindow;
- (void) endConnectionAttempt;
@end
