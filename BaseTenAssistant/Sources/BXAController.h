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
#import <BaseTen/BXPGSQLScriptReader.h>

@class MKCBackgroundView;
@class MKCPolishedCornerView;
@class BXAImportController;
@class MKCStackView;
@class RKRegex;


@interface BXAController : NSObject 
{
	MKCPolishedCornerView* mCornerView;
	NSButtonCell* mInspectorButtonCell;
	BXAImportController* mImportController;
	BXDataModelCompiler* mCompiler;
	BXPGSQLScriptReader* mReader;
	NSNumber* mBundledSchemaVersionNumber;
	
	RKRegex* mCompilationErrorRegex;
	RKRegex* mCompilationFailedRegex;
	
	IBOutlet BXDatabaseContext* mContext;
	IBOutlet NSDictionaryController* mEntitiesBySchema;
	IBOutlet NSDictionaryController* mEntities;
	IBOutlet NSDictionaryController* mAttributes;

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
	IBOutlet NSButton* mProgressCancelButton;
	
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
	//Patch by Tim Bedford 2008-08-11
	IBOutlet NSPopUpButton* mBonjourPopUpButton;
    
	NSSavePanel* mSavePanel;
	IBOutlet NSView* mDataModelExportView;
	IBOutlet NSPopUpButton* mModelFormatButton;
	
	NSNetServiceBrowser* mServiceBrowser;
    NSMutableArray* mServices; // Keeps track of available services
    BOOL mSearching; // Keeps track of Bonjour search status
	//End patch
	
	IBOutlet NSPanel* mMomcErrorPanel;
	IBOutlet MKCStackView* mMomcErrorView;
			
	BOOL mLastSelectedEntityWasView;
	BOOL mDeniedSchemaInstall;
	BOOL mExportUsingFkeyNames;
	BOOL mExportUsingTargetRelationNames;
}

@property (readonly) BOOL hasBaseTenSchema;
@property (readonly) NSWindow* mainWindow;
@property (readwrite, retain) NSSavePanel* savePanel;
@property (readwrite, assign) BOOL exportsUsingFkeyNames;
@property (readwrite, assign) BOOL exportsUsingTargetRelationNames;


- (id) init; //Patch by Tim Bedford 2008-08-11
- (void) process: (BOOL) newState entity: (BXEntityDescription *) entity;
- (void) process: (BOOL) newState attribute: (BXAttributeDescription *) attribute;
- (void) logAppend: (NSString *) string;
- (void) finishedImporting;
- (NSError *) schemaInstallError;
- (BOOL) schemaInstallDenied;
- (void) upgradeBaseTenSchema;
- (void) refreshCaches: (SEL) callback;
@end


@interface BXAController (IBActions)
- (IBAction) disconnect: (id) sender;
- (IBAction) terminate: (id) sender;
- (IBAction) chooseBonjourService: (id) sender; //Patch by Tim Bedford 2008-08-11
- (IBAction) connect: (id) sender;
- (IBAction) importDataModel: (id) sender;
- (IBAction) dismissMomcErrorPanel: (id) sender;
- (IBAction) exportLog: (id) sender; //Patch by Tim Bedford 2008-08-11
- (IBAction) exportObjectModel: (id) sender;
- (IBAction) clearLog: (id) sender;
- (IBAction) displayLogWindow: (id) sender;

- (IBAction) reload: (id) sender;

- (IBAction) refreshCacheTables: (id) sender;
- (IBAction) prune: (id) sender;

- (IBAction) getInfo: (id) sender; //Patch by Tim Bedford 2008-08-11
- (IBAction) toggleMainWindow: (id) sender; //Patch by Tim Bedford 2008-08-11
- (IBAction) toggleInspector: (id) sender; //Patch by Tim Bedford 2008-08-11

- (IBAction) upgradeSchema: (id) sender;
- (IBAction) removeSchema: (id) sender;
- (IBAction) cancelSchemaInstall: (id) sender;

- (IBAction) changeModelFormat: (id) sender;

- (IBAction) openHelp: (id) sender; //Patch by Tim Bedford 2008-08-12
@end


@interface BXAController (ProgressPanel)
- (void) displayProgressPanel: (NSString *) message;
- (void) hideProgressPanel;
- (void) setProgressMin: (double) min max: (double) max;
- (void) setProgressValue: (double) value;
- (void) advanceProgress;
@end


@interface BXAController (Delegation) <BXDatabaseContextDelegate, BXDataModelCompilerDelegate, BXPGSQLScriptReaderDelegate>
- (void) alertDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) ctx;
- (void) importOpenPanelDidEnd: (NSOpenPanel *) panel returnCode: (int) returnCode contextInfo: (void *) contextInfo;

- (void) reloadAfterRefresh: (PGTSResultSet *) res;
- (void) disconnectAfterRefresh: (PGTSResultSet *) res;
- (void) terminateAfterRefresh: (PGTSResultSet *) res;
@end

//Patch by Tim Bedford 2008-08-11
@interface BXAController (NSSplitViewDelegate)
- (float)splitView:(NSSplitView *)splitView constrainMinCoordinate:(float)proposedCoordinate ofSubviewAt:(int)index;
- (float)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(float)proposedCoordinate ofSubviewAt:(int)index;
- (void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize;
@end

@interface BXAController (NetServiceMethods)
- (void)applyNetService:(NSNetService*)netService;
- (void)updateBonjourUI;
- (void)handleNetServiceBrowserError:(NSNumber *)error;
- (void)handleNetServiceError:(NSNumber *)error withService:(NSNetService *)service;
@end

@interface BXAController (NSSavePanelDelegate)
//End patch.
- (void) exportLogSavePanelDidEnd: (NSSavePanel *) sheet returnCode: (int) returnCode contextInfo: (void *) contextInfo;
- (void) exportModelSavePanelDidEnd: (NSSavePanel *) sheet returnCode: (int) returnCode contextInfo: (void *) contextInfo;
//Patch by Tim Bedford 2008-08-11
@end

@interface BXAController (NetServiceBrowserDelegate)
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser;
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser;
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
			 didNotSearch:(NSDictionary *)errorDict;
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
		   didFindService:(NSNetService *)aNetService
			   moreComing:(BOOL)moreComing;
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
		 didRemoveService:(NSNetService *)aNetService
			   moreComing:(BOOL)moreComing;
@end


@interface BXAController (NSNetServiceDelegate)
- (void)resolveNetServiceAtIndex:(NSInteger)index;
- (void)netServiceDidResolveAddress:(NSNetService *)netService;
- (void)netService:(NSNetService *)netService
	 didNotResolve:(NSDictionary *)errorDict;
@end
//End patch
