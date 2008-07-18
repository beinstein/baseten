//
// BXAImportController.m
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

#import "BXAImportController.h"
#import "BXAController.h"
#import "MKCPolishedHeaderView.h"
#import "MKCPolishedCornerView.h"
#import <BaseTen/PGTSHOM.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/PGTSConnection.h>
#import <BaseTen/PGTSResultSet.h>
#import <BaseTen/BXPGInterface.h>
#import <BaseTen/BXPGTransactionHandler.h>
#import <BaseTen/BXPGEntityImporter.h>

static NSString* kBXAShouldImportKey = @"kBXAShouldImportKey";


@interface NSEntityDescription (BXAImportControllerAdditions)
- (BOOL) shouldImportBXA;
- (void) setShouldImportBXA: (BOOL) flag;
@end


@implementation NSEntityDescription (BXAImportControllerAdditions)
- (BOOL) shouldImportBXA
{
	return [[[self userInfo] objectForKey: kBXAShouldImportKey] boolValue];
}

- (void) setShouldImportBXA: (BOOL) flag
{
	NSMutableDictionary* userInfo = [[self userInfo] mutableCopy];
	[userInfo setObject: [NSNumber numberWithBool: flag] forKey: kBXAShouldImportKey];
	[self setUserInfo: userInfo];
}
@end



@implementation BXAImportController
@synthesize objectModel = mModel, schemaName = mSchemaName, databaseContext = mContext, controller = mController;

- (void) windowDidLoad
{
    NSDictionary* lightColours = [MKCPolishedHeaderView lightColours];
	[mLeftHeaderView setColours: lightColours];
	[mLeftHeaderView setDrawingMask: kMKCPolishDrawLeftAccent | kMKCPolishDrawBottomLine | 
	 kMKCPolishDrawTopLine | kMKCPolishDrawSeparatorLines];
	
	[mRightHeaderView setColours: lightColours];
	[mRightHeaderView setDrawingMask: kMKCPolishDrawLeftLine | kMKCPolishDrawTopLine | kMKCPolishDrawBottomLine];
	
    {
        NSRect cornerRect = NSMakeRect (0.0, 0.0, 15.0, 20.0);
        MKCPolishedCornerView* cornerView = [[[MKCPolishedCornerView alloc] initWithFrame: cornerRect] autorelease];
        [cornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopLine | kMKCPolishDrawRightLine];
        [cornerView setColours: lightColours];
        [mTableView setCornerView: cornerView];
        
        cornerRect.size.width -= 5.0;
        cornerView = [[[MKCPolishedCornerView alloc] initWithFrame: cornerRect] autorelease];
        [cornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopLine | kMKCPolishDrawRightLine];
        [cornerView setColours: lightColours];
        [mFieldView setCornerView: cornerView];
    }
    
    {
        NSColor* lightBackgroundColor = [NSColor colorWithDeviceWhite: 222.0 / 255.0 alpha: 1.0];
        [[self window] setBackgroundColor: lightBackgroundColor];
    }
	
	NSMutableArray* configurations = [[mModel configurations] mutableCopy];
	[configurations insertObject: @"Default Configuration" atIndex: 0]; //FIXME: localization.
	[self willChangeValueForKey: @"entitiesForSelectedConfiguration"];
	[mConfigurations setContent: configurations];		
	[self didChangeValueForKey: @"entitiesForSelectedConfiguration"];
	
	[self selectedConfiguration: nil];	
}

- (void) showPanel
{
	[NSApp beginSheet: [self window] modalForWindow: [mController mainWindow] modalDelegate: self 
	   didEndSelector: @selector (importPanelDidEnd:returnCode:contextInfo:) contextInfo: NULL];
}

- (void) entityImporterAdvanced: (BXPGEntityImporter *) importer
{
	[mController advanceProgress];
}

- (void) continueEnabling
{
	NSError* error = nil;
	[mEntityImporter enableEntities: &error];
	if (error)
	{
		[NSApp presentError: error modalForWindow: [mController mainWindow] 
				   delegate: nil didPresentSelector: NULL contextInfo: NULL];
	}
}

- (void) entityImporter: (BXPGEntityImporter *) importer finishedImporting: (BOOL) succeeded error: (NSError *) error
{
	[mController hideProgressPanel];

	if (succeeded)
	{
		if ([mController hasBaseTenSchema])
		{
			[self continueEnabling];
			[mController finishedImporting];
		}
		else
		{
			[NSApp presentError: BXASchemaInstallError () modalForWindow: [mController mainWindow] 
					   delegate: self didPresentSelector: @selector (schemaErrorEnded:contextInfo:) contextInfo: NULL];
		}
	}
	else
	{
		[NSApp presentError: error modalForWindow: [mController mainWindow]
				   delegate: nil didPresentSelector: NULL contextInfo: NULL];
	}
}

- (void) continueImport: (BOOL) modifyDatabase
{
	NSArray* statements = [mEntityImporter importStatements];
	if (modifyDatabase)
	{
		[mController setProgressMin: 0.0 max: (double) [statements count]];
		//FIXME: progress cancel?
		[mController displayProgressPanel: @"Importing data model"];
		[mEntityImporter importEntities];
	}
	else
	{
		[mController displayLogWindow: nil];
		[mController logAppend: @"\n\n\n---------- Beginning dry run ----------\n\n"];
		for (NSString* statement in statements)
		{
			[mController logAppend: statement];
			[mController logAppend: @"\n"];
		}
		[mController logAppend: @"\n----------- Ending dry run ------------\n\n\n"];
	}
}

static int 
ShouldImport (id entity)
{
	return ([entity shouldImportBXA]);
}

- (void) import: (BOOL) modifyDatabase usingSheet: (BOOL) useSheet
{
	NSArray* importedEntities = [[mEntities arrangedObjects] PGTSSelectFunction: &ShouldImport];

	if (! mEntityImporter)
	{
		mEntityImporter = [[BXPGEntityImporter alloc] init];		
		[mEntityImporter setDatabaseContext: mContext];
		[mEntityImporter setDelegate: self];
	}
	[mEntityImporter setSchemaName: mSchemaName];
	[mEntityImporter setEntities: importedEntities];
	
	NSArray* errors = nil;
	[mEntityImporter importStatements: &errors];
	
	if (0 < [errors count])
	{
		[mImportErrors setContent: errors];

		//Not sure if window is allowed to be nil, but running a modal session doesn't fit into the same abstraction pattern.
		[NSApp beginSheet: mChangePanel modalForWindow: useSheet ? [mController mainWindow] : nil
			modalDelegate: self didEndSelector: @selector (importErrorSheetDidEnd:returnCode:contextInfo:) 
			  contextInfo: (void *)(modifyDatabase ? 1 : 0)];
	}
	else
	{
		[self continueImport: modifyDatabase];
	}	
}

			
- (void) schemaErrorEnded: (BOOL) didRecover contextInfo: (void *) contextInfo
{
	if (didRecover)
		[self continueEnabling];
	[mController finishedImporting];
}

- (void) importErrorSheetDidEnd: (NSWindow *) sheet returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
	if (returnCode)
	{
		[self continueImport: (int) contextInfo];
	}
}


- (void) importPanelDidEnd: (NSWindow *) sheet returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
	if (returnCode)
		[self import: YES usingSheet: YES];
}
@end
	
	
@implementation BXAImportController (IBActions)
- (IBAction) endErrorPanel: (id) sender
{
	[mChangePanel orderOut: nil];
	[NSApp endSheet: mChangePanel returnCode: [sender tag]];
}

- (IBAction) endImportPanel: (id) sender
{
	NSWindow* panel = [self window];
	[panel orderOut: nil];
	[NSApp endSheet: panel returnCode: [sender tag]];
}

- (IBAction) dryRun: (id) sender
{
	[self import: NO usingSheet: NO];
}

- (IBAction) selectedConfiguration: (id) sender
{
	NSArray* content = nil;
	if (0 == [sender indexOfSelectedItem])
		content = [mModel entities];
	else
	{
		NSMenuItem* selectedItem = [sender selectedItem];
		NSString* title = [selectedItem title];
		content = [mModel entitiesForConfiguration: title];
	}
	
	[mEntities setContent: content];
}
@end
