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
#import "MKCEventPassingTextField.h"
#import "Additions.h"
#import <BaseTen/PGTSHOM.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/PGTSConnection.h>
#import <BaseTen/PGTSResultSet.h>
#import <BaseTen/BXPGInterface.h>
#import <BaseTen/BXPGTransactionHandler.h>
#import <BaseTen/BXPGEntityImporter.h>

static NSString* kBXAShouldImportKey = @"kBXAShouldImportKey";
static NSString* kBXATextColorKey = @"kBXATextColorKey";


@interface NSEntityDescription (BXAImportControllerAdditions)
- (BOOL) shouldImportBXA;
- (void) setShouldImportBXA: (BOOL) flag;
@end


@implementation NSEntityDescription (BXAImportControllerAdditions)
- (NSColor *) BXATextColor
{
	return ([[self userInfo] objectForKey: kBXATextColorKey] ?: [NSColor blackColor]);
}

- (void) setBXATextColor: (NSColor *) aColor
{
	NSColor* currentColor = [self BXATextColor];
	if (![currentColor isEqual: aColor])
	{
		NSMutableDictionary* userInfo = [[self userInfo] mutableCopy];		
		[userInfo setObject: aColor forKey: kBXATextColorKey];
		[self setUserInfo: userInfo];
	}
}

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

- (void) checkNameConflicts
{
	BOOL hasConflicts = NO;
	NSString* schemaName = mSchemaName ?: @"public";
	
	for (NSEntityDescription* entity in [mEntities arrangedObjects])
	{
		if ([mContext entity: entity existsInSchema: schemaName error: NULL])
		{
			hasConflicts = YES;
			[entity setBXATextColor: [NSColor redColor]];
		}
		else
		{
			[entity setBXATextColor: [NSColor blackColor]];
		}
	}
	mHasNameConflicts = hasConflicts;
}

- (void) windowDidLoad
{
	NSDictionary* lightColours = [MKCPolishedHeaderView lightColours];
	[mLeftHeaderView setColours: lightColours];
	[mLeftHeaderView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopLine | kMKCPolishDrawSeparatorLines];
	
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
	
	//The text "Tables" spans column borders, so we place it differently.
	{
		NSRect frame = [mLeftHeaderView frame];
		frame.origin.x += 5.0;
		NSTextField* textField = [[MKCEventPassingTextField alloc] initWithFrame: frame];
		[textField setBordered: NO];
		[textField setEditable: NO];
		[textField setSelectable: NO];
		[textField setDrawsBackground: NO];
		[textField setStringValue: @"Tables"]; //FIXME: localization.
		[textField makeEtchedSmall: NO];
		[mLeftHeaderView addSubview: textField];
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

- (void) entityImporter: (BXPGEntityImporter *) importer finishedImporting: (BOOL) succeeded error: (NSError *) error
{
	[mController hideProgressPanel];

	if (! succeeded)
	{
		[NSApp presentError: error modalForWindow: [mController mainWindow]
				   delegate: nil didPresentSelector: NULL contextInfo: NULL];
	}
	
	[NSApp stopModalWithCode: succeeded];	
}

static int 
ShouldImport (id entity)
{
	return ([entity shouldImportBXA]);
}

- (void) import: (BOOL) modifyDatabase usingSheet: (BOOL) useSheet
{
	BOOL shouldContinue = YES;
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
	NSArray* statements = [mEntityImporter importStatements: &errors];
	
	if (0 < [errors count])
	{
		shouldContinue = NO;
		[mImportErrors setContent: errors];

		if (useSheet)
		{
			[NSApp beginSheet: mChangePanel modalForWindow: [mController mainWindow]
				modalDelegate: self didEndSelector: NULL contextInfo: NULL];
			shouldContinue = [NSApp runModalForWindow: [mController mainWindow]];
		}
		else
		{
			shouldContinue = [NSApp runModalForWindow: mChangePanel];
		}
	}
	
	if (shouldContinue)
	{
		if (! modifyDatabase)
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
		else
		{
			if (mHasNameConflicts)
			{
				shouldContinue = NO;
				NSString* message = @"Entities exist in the database that have the same names as some of those selected for import. Would you like to replace the existing entities?";
				NSAlert* alert = [NSAlert alertWithMessageText: @"Replace existing entities with matching names?"
												 defaultButton: @"Replace" alternateButton: @"Cancel" otherButton: nil 
									 informativeTextWithFormat: message];
				[alert layout];
				NSArray* buttons = [alert buttons];
				[[buttons objectAtIndex: 0] setKeyEquivalent: @""];
				[[buttons objectAtIndex: 1] setKeyEquivalent: @"\r"];
				
				[alert beginSheetModalForWindow: [mController mainWindow] modalDelegate: self 
								 didEndSelector: @selector (nameConflictAlertDidEnd:returnCode:contextInfo:) contextInfo: NULL];
				shouldContinue = [NSApp runModalForWindow: [mController mainWindow]];
			}
			
			if (! shouldContinue)
				[self showPanel];
			else
			{
				[mController setProgressMin: 0.0 max: (double) [statements count]];
				//FIXME: progress cancel?
				[mController displayProgressPanel: @"Importing data model"];
				[mController logAppend: @"\n\n\n---------- Beginning import -----------\n\n"];
				[mEntityImporter importEntities];
				
				shouldContinue = [NSApp runModalForWindow: [mController mainWindow]];
				[mController logAppend: @"\n------------ Ending import ------------\n\n\n"];
				if (shouldContinue)
				{
					if (! [mController hasBaseTenSchema])
					{
						shouldContinue = NO;
						if (! [mController schemaInstallDenied])
						{
							NSError* error = [mController schemaInstallError];
							[NSApp presentError: error modalForWindow: [mController mainWindow] 
									   delegate: self didPresentSelector: @selector (errorEnded:contextInfo:) contextInfo: NULL];
							shouldContinue = [NSApp runModalForWindow: [mController mainWindow]];
						}
					}
					
					if (shouldContinue)
					{
						NSError* error = nil;
						[mEntityImporter enableEntities: &error];
						if (error)
						{
							[NSApp presentError: error modalForWindow: [mController mainWindow] 
									   delegate: nil didPresentSelector: NULL contextInfo: NULL];
							[NSApp runModalForWindow: [mController mainWindow]];
						}					
					}
				}
				[mController finishedImporting];
			}
		}
	}
}

			
- (void) errorEnded: (BOOL) didRecover contextInfo: (void *) contextInfo
{
	[NSApp stopModalWithCode: didRecover];
}

- (void) nameConflictAlertDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) ctx
{
	[NSApp stopModalWithCode: (NSAlertDefaultReturn == returnCode ? YES : NO)];
}

- (void) importPanelDidEnd: (NSWindow *) sheet returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
	if (returnCode)
		[self import: YES usingSheet: YES];
}
@end
	
	
@implementation BXAImportController (IBActions)
- (IBAction) endEditingForSchemaName: (id) sender
{
	[self checkNameConflicts];
}

- (IBAction) endErrorPanel: (id) sender
{
	[mChangePanel orderOut: nil];
	[NSApp endSheet: mChangePanel];
	[NSApp stopModalWithCode: [sender tag]];
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
	[self checkNameConflicts];
}
@end
