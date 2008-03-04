//
// ImportController.h
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
@class EntityConverter;
@class Controller;
@class PGTSConnection;


@interface ImportController : NSObject 
{
    @public
    Controller* mController;
    NSWindow* mMainWindow;
    
    @protected
    PGTSConnection* mConnection;
    
    NSString* mMomcTargetName;
    NSTask* mMomcTask;
    NSManagedObjectModel* mManagedObjectModel;
    EntityConverter* mEntityConverter;
    
    
    BOOL mAddsSerialColumns;
    BOOL mMakesForeignKeys;
    
    NSString* mSchemaName;

    IBOutlet NSPanel* mImportPanel;
    IBOutlet NSTableView* mEntityTable;
    IBOutlet NSTableColumn* mEntitySelectedColumn;
    IBOutlet NSTableColumn* mEntityNameColumn;
    IBOutlet NSTableView* mFieldTable;
    IBOutlet NSTableColumn* mFieldNameColumn;
    IBOutlet NSButton* mAddSerialButton;
    IBOutlet NSButton* mAddForeignKeysButton;
    IBOutlet NSPopUpButton* mConfigurationButton;
    IBOutlet NSArrayController* mImportArrayController;    
    IBOutlet NSFormCell* mSchemaNameField;
}

- (void) loadNibAndListen;
- (void) importModelAtPath: (NSString *) path;
- (void) compileModelAtPath: (NSString *) path;
- (NSError *) importEntities: (NSArray *) entities dryRun: (BOOL) dryRun;
@end


@interface ImportController (IBActions)
- (IBAction) changeVisibleConfiguration: (id) sender;
- (IBAction) changeSchemaName: (id) sender;
- (IBAction) endImportPanel: (id) sender;
- (IBAction) dryRun: (id) sender;
@end


@interface ImportController (Accessors)
- (BOOL) addsSerialColumns;
- (void) setAddsSerialColumns: (BOOL) flag;

- (BOOL) makesForeignKeys;
- (void) setMakesForeignKeys: (BOOL) flag;

- (NSString *) schemaName;
- (void) setSchemaName: (NSString *) aSchemaName;

- (void) setMomcTargetName: (NSString *) aMomcTargetName;
- (void) setMomcTask: (NSTask *) aMomcTask;
- (void) setManagedObjectModel: (NSManagedObjectModel *) aManagedObjectModel;

- (void) setConnection: (PGTSConnection *) aConnection;

@end
