//
// Controller.h
// BaseTen Setup
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
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
#import "Entity.h"
#import "PostgresEntityConverter.h"


@class ImportController;
@class PGTSConnection;
@class PGTSResultSet;
@class MKCPolishedCornerView;
@class MKCBackgroundView;
@protocol PGTSConnectionDelegate;


@interface Entity (BaseTenSetupApplicationAdditions)
- (NSColor *) textColor;
@end


@interface Controller : NSObject <PGTSConnectionDelegate>
{
    @protected    
    PGTSConnection* mConnection;
    NSDictionary* mConnectionDict;
    ImportController* mImportController;
    MKCPolishedCornerView* mCornerView;
    NSButtonCell* mInspectorButtonCell;
    
    @public
    IBOutlet NSTableView* mDBSchemaView;
    IBOutlet NSTableColumn* mSchemaNameColumn;
    IBOutlet NSTableView* mDBTableView;
    IBOutlet NSTableColumn* mTableNameColumn;
    IBOutlet NSTableColumn* mTableEnabledColumn;
        
    IBOutlet NSArrayController* mSchemaController;
    IBOutlet NSArrayController* mTableController;
    IBOutlet NSWindow* mMainWindow;
    IBOutlet NSPanel* mConnectPanel;
    IBOutlet NSPanel* mProgressPanel;
    
	IBOutlet MKCBackgroundView* mToolbar;
    IBOutlet NSTextField* mStatusTextField;

    IBOutlet id mHostCell;
    IBOutlet id mPortCell;
    IBOutlet id mDBNameCell;
    IBOutlet id mUserNameCell;
    IBOutlet NSSecureTextField* mPasswordField;
    
    IBOutlet NSProgressIndicator* mProgressIndicator;
    IBOutlet NSTextField* mProgressField;
    
    IBOutlet NSWindow* mLogWindow;
    IBOutlet NSTextView* mLogView;
    
    //Inspector
    IBOutlet NSWindow* mInspectorWindow;
    @public
    IBOutlet NSTableView* mInspectorTable;
    IBOutlet NSTableColumn* mTypeColumn;
    IBOutlet NSTableColumn* mNameColumn;
    IBOutlet NSTableColumn* mDetailColumn;
	
	@protected
	BOOL mAwaken;
	BOOL mTerminating;
}

- (void) awakeFromNib;
- (BOOL) versionCheck;
- (char *) storePassword;
- (void) handleVersionCheckError: (PGTSResultSet *) res;

- (void) setConnection: (PGTSConnection *) aConnection;
- (void) setConnectionDict: (NSDictionary *) aConnectionDict;

- (void) continueTermination;
- (void) continueDisconnect;
@end


@interface Controller (IBActions)

- (IBAction) terminate: (id) sender;
- (IBAction) connect: (id) sender;
- (IBAction) disconnect: (id) sender;
- (IBAction) reload: (id) sender;
- (IBAction) changeObservingStatusByBinding: (id) sender;
- (IBAction) changeObservingStatus: (id) sender;
- (IBAction) importDataModel: (id) sender;
- (IBAction) clearLog: (id) sender;
- (IBAction) reloadTables: (id) sender;

@end


@interface Controller (Delegation)

- (void) PGTSConnectionEstablished: (PGTSConnection *) connection;
- (void) PGTSConnectionFailed: (PGTSConnection *) aConnection;
- (void) alertConnectionFailedDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo;
- (void) alertAlterDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo;
- (BOOL) validateMenuItem: (NSMenuItem *) menuItem;

@end


@interface Controller (ProgressPanel)
- (void) displayProgressPanel: (NSString *) message;
- (void) hideProgressPanel;
@end


@interface Controller (Logging)
- (void) logAppend: (NSString *) string;
@end


@interface Controller (InspectorDataSource)
- (BOOL) allowEnablingForRow: (NSInteger) rowIndex;
@end