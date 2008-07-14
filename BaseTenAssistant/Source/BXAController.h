//
// BXAController.h
// BaseTen Assistant
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

#import <Cocoa/Cocoa.h>
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDataModelCompiler.h>

@class MKCBackgroundView;
@class MKCPolishedCornerView;
@class BXAImportController;


@interface BXAController : NSObject 
{
	MKCPolishedCornerView* mCornerView;
	NSButtonCell* mInspectorButtonCell;
	BXAImportController* mImportController;
	BXDataModelCompiler* mCompiler;
	
	IBOutlet BXDatabaseContext* mContext;
	IBOutlet NSDictionaryController* mEntitiesBySchema;
	IBOutlet NSDictionaryController* mEntities;
	IBOutlet NSDictionaryController* mAttributes;
	IBOutlet NSArrayController* mMomcErrors;

	IBOutlet NSWindow* mMainWindow;
	IBOutlet NSTableView* mDBSchemaView;
	IBOutlet NSTableView* mDBTableView;
	IBOutlet MKCBackgroundView* mToolbar;
	IBOutlet NSTableColumn* mTableNameColumn;
	IBOutlet NSTableColumn* mTableEnabledColumn;
	IBOutlet NSTextField* mStatusTextField;
	
	IBOutlet NSPanel* mProgressPanel;
	IBOutlet NSProgressIndicator* mProgressIndicator;
	IBOutlet NSTextField* mProgressField;
	
	IBOutlet NSPanel* mInspectorWindow;
	IBOutlet NSTableView* mAttributeTable;
	IBOutlet NSTableColumn* mAttributeIsPkeyColumn;
	
	IBOutlet NSWindow* mLogWindow;
	IBOutlet NSTextView* mLogView;
	
	IBOutlet NSPanel* mConnectPanel;
    IBOutlet id mHostCell;
    IBOutlet id mPortCell;
    IBOutlet id mDBNameCell;
    IBOutlet id mUserNameCell;
    IBOutlet NSSecureTextField* mPasswordField;	
	
	IBOutlet NSPanel* mMomcErrorPanel;
		
	BOOL mLastSelectedEntityWasView;
}

@property (readonly) BOOL hasBaseTenSchema;


- (void) process: (BOOL) newState entity: (BXEntityDescription *) entity;
- (void) process: (BOOL) newState attribute: (BXAttributeDescription *) attribute;
- (void) logAppend: (NSString *) string;
@end


@interface BXAController (IBActions)
- (IBAction) disconnect: (id) sender;
- (IBAction) terminate: (id) sender;
- (IBAction) connect: (id) sender;
- (IBAction) importDataModel: (id) sender;
- (IBAction) dismissMomcErrorPanel: (id) sender;
- (IBAction) clearLog: (id) sender;
@end


@interface BXAController (ProgressPanel)
- (void) displayProgressPanel: (NSString *) message;
- (void) hideProgressPanel;
@end


@interface BXAController (Delegation) <BXDataModelCompilerDelegate>
@end
