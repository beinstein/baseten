//
// BXNetServiceConnector.h
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

@class BXPanel;
@class BXAuthenticationPanel;

#import <Cocoa/Cocoa.h>
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXConnectionSetupManagerProtocol.h>


@interface BXNetServiceConnector : NSObject <BXConnectionSetupManager>
{
	IBOutlet BXDatabaseContext* databaseContext;
	IBOutlet NSWindow* modalWindow;
	
	BXAuthenticationPanel* mAuthenticationPanel;
    BXPanel* mPanel;
}
- (IBAction) connect: (id) sender;
- (void) displayAuthenticationPanel;
- (void) setDatabaseContext: (BXDatabaseContext *) aContext;
- (void) setPanel: (BXPanel *) aPanel;
- (void) setAuthenticationPanel: (BXAuthenticationPanel *) aPanel;

@end
