//
// BXAImportController.h
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
#import <BaseTen/BXPGEntityImporter.h>
@class MKCPolishedHeaderView;
@class BXAController;


@interface BXAImportController : NSWindowController <BXPGEntityImporterDelegate>
{
	BXAController* mController;
	BXDatabaseContext* mContext;
	NSManagedObjectModel* mModel;
	NSString* mSchemaName;
	BXPGEntityImporter* mEntityImporter; //Currently we only support PostgreSQL.
	
	IBOutlet NSArrayController* mConfigurations;
	IBOutlet NSArrayController* mEntities;
	IBOutlet NSArrayController* mProperties;
	
	IBOutlet MKCPolishedHeaderView* mLeftHeaderView;
	IBOutlet MKCPolishedHeaderView* mRightHeaderView;
	
	IBOutlet NSTableView* mTableView;
	IBOutlet NSTableView* mFieldView;
	
	IBOutlet NSArrayController* mImportErrors;
	IBOutlet NSPanel* mChangePanel;
}
@property (readwrite, retain) BXAController* controller;
@property (readwrite, retain) NSManagedObjectModel* objectModel;
@property (readwrite, retain) NSString* schemaName;
@property (readwrite, retain) BXDatabaseContext* databaseContext;
- (void) showPanel;
@end


@interface BXAImportController (IBActions)
- (IBAction) selectedConfiguration: (id) sender;
- (IBAction) endErrorPanel: (id) sender;
- (IBAction) endImportPanel: (id) sender;
- (IBAction) dryRun: (id) sender;
@end
