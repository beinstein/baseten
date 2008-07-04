//
// ImportController.m
// BaseTen Setup
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

#import <PGTS/PGTS.h>
#import <PGTS/PGTSFunctions.h>

#import "ImportController.h"
#import "Controller.h"
#import "Entity.h"
#import "Constants.h"
#import "PostgresEntityConverter.h"
#import "MKCPolishedHeaderView.h"
#import "MKCPolishedCornerView.h"


@implementation ImportController

- (id) init
{
    if ((self = [super init]))
    {
        mAddsSerialColumns = YES;
        mMakesForeignKeys = YES;
    }
    return self;
}

- (void) dealloc
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    [mMomcTargetName release];
    [mMomcTask release];
    [mManagedObjectModel release];
    [mSchemaName release];
    [mEntityConverter release];
    [super dealloc];
}

- (void) awakeFromNib
{
    NSDictionary* lightColours = [MKCPolishedHeaderView lightColours];
	NSRect headerRect = NSMakeRect (0.0, 0.0, 20.0, 20.0);
    {        
        MKCPolishedHeaderView* headerView = [[[MKCPolishedHeaderView alloc] initWithFrame: headerRect] autorelease];
        headerRect.size.width = [mFieldTable bounds].size.width;
        [headerView setColours: lightColours];
        [headerView setDrawingMask: kMKCPolishDrawLeftAccent | kMKCPolishDrawBottomLine | 
            kMKCPolishDrawTopLine | kMKCPolishDrawSeparatorLines];
        [mFieldTable setHeaderView: headerView];
	}
        
	{
		headerRect.size.width = [mEntityTable bounds].size.width;
        MKCPolishedHeaderView* headerView = [[[MKCPolishedHeaderView alloc] initWithFrame: headerRect] autorelease];
        [headerView setColours: lightColours];
        [headerView setDrawingMask: kMKCPolishDrawLeftLine | kMKCPolishDrawTopLine | kMKCPolishDrawBottomLine];
        [mEntityTable setHeaderView: headerView];
        
        headerRect = [headerView convertRect: headerRect toView: nil];
        headerRect.origin.x -= 1.0;
        headerRect.size.width = 1.0;
    }

    {
        NSRect cornerRect = NSMakeRect (0.0, 0.0, 15.0, 20.0);
        MKCPolishedCornerView* cornerView = [[[MKCPolishedCornerView alloc] initWithFrame: cornerRect] autorelease];
        [cornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopLine | kMKCPolishDrawRightLine];
        [cornerView setColours: lightColours];
        [mEntityTable setCornerView: cornerView];
        
        cornerRect.size.width -= 5.0;
        cornerView = [[[MKCPolishedCornerView alloc] initWithFrame: cornerRect] autorelease];
        [cornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopLine | kMKCPolishDrawRightLine];
        [cornerView setColours: lightColours];
        [mFieldTable setCornerView: cornerView];
    }
    
    {
        NSColor* lightBackgroundColor = [NSColor colorWithDeviceWhite: 222.0 / 255.0 alpha: 1.0];
        [mImportPanel setBackgroundColor: lightBackgroundColor];
    }    
}

- (void) loadNibAndListen
{
    mEntityConverter = [[PostgresEntityConverter alloc] init];
    [mEntityConverter setConnection: mConnection];

    [NSBundle loadNibNamed: @"Import" owner: self];
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                                                        selector: @selector (momcReceivedTarget:) 
                                                            name: kBXMomcHelperTargetFile
                                                          object: nil
                                              suspensionBehavior: NSNotificationSuspensionBehaviorDeliverImmediately];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector (tableViewSelectionDidChange:)
                                                 name: NSTableViewSelectionDidChangeNotification
                                               object: mController->mInspectorTable];
}

- (void) importModelAtPath: (NSString *) path
{    
    NSURL* location = [NSURL fileURLWithPath: path];
    [self setManagedObjectModel: [[[NSManagedObjectModel alloc] initWithContentsOfURL: location] autorelease]];
    [mController->mInspectorTable setDataSource: self];
    
    //Configurations
    NSArray* configurations = [mManagedObjectModel configurations];
    if (0 < [configurations count])
        [mConfigurationButton addItemsWithTitles: configurations];
    
    [self changeVisibleConfiguration: nil];
    [self changeSchemaName: nil];
    [self tableViewSelectionIsChanging: nil];
    [NSApp beginSheet: mImportPanel modalForWindow: mMainWindow modalDelegate: nil didEndSelector: NULL contextInfo: NULL];
}

- (void) compileModelAtPath: (NSString *) path
{
    //Run momc
    NSPipe* outPipe = [NSPipe pipe];
    [self setMomcTask: [[[NSTask alloc] init] autorelease]];
    [mMomcTask setLaunchPath: [[NSBundle mainBundle] pathForAuxiliaryExecutable: @"MomcHelper"]];
    [mMomcTask setArguments: [NSArray arrayWithObject: path]];
    [mMomcTask setStandardError: outPipe];
    [mMomcTask setStandardOutput: outPipe];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector (momcTaskEnded:) 
                                                 name: NSTaskDidTerminateNotification object: mMomcTask];
    [mMomcTask launch];
}

- (NSError *) importEntities: (NSArray *) entities dryRun: (BOOL) dryRun
{
    NSError* retval = nil;
    
    [mEntityConverter setAddsIDColumns: mAddsSerialColumns];
    [mEntityConverter setAddsForeignKeys: mMakesForeignKeys];
    [mEntityConverter setDryRun: dryRun];
    [mEntityConverter setController: mController];
    
    retval = [mEntityConverter importEntities: entities];
    return retval; 
}

@end


@implementation ImportController (Accessors)

- (BOOL) addsSerialColumns
{
    return mAddsSerialColumns;
}

- (void) setAddsSerialColumns: (BOOL) flag
{
    mAddsSerialColumns = flag;
}

- (BOOL) makesForeignKeys
{
    return mMakesForeignKeys;
}

- (void) setMakesForeignKeys: (BOOL) flag
{
    mMakesForeignKeys = flag;
}

- (NSString *) schemaName
{
    return mSchemaName; 
}

- (void) setSchemaName: (NSString *) aSchemaName
{
    if (mSchemaName != aSchemaName) 
    {
        [mSchemaName release];
        mSchemaName = [aSchemaName retain];
    }
}

- (void) setMomcTargetName: (NSString *) aMomcTargetName
{
    if (mMomcTargetName != aMomcTargetName) {
        [mMomcTargetName release];
        mMomcTargetName = [aMomcTargetName retain];
    }
}

- (void) setMomcTask: (NSTask *) aMomcTask
{
    if (mMomcTask != aMomcTask) {
        [mMomcTask release];
        mMomcTask = [aMomcTask retain];
    }
}

- (void) setManagedObjectModel: (NSManagedObjectModel *) aManagedObjectModel
{
    if (mManagedObjectModel != aManagedObjectModel) {
        [mManagedObjectModel release];
        mManagedObjectModel = [aManagedObjectModel retain];
    }
}

- (void) setConnection: (PGTSConnection *) aConnection
{
    if (mConnection != aConnection) 
    {
        [mConnection release];
        mConnection = [aConnection retain];
    }
}

@end


@implementation ImportController (Delegation)

- (void) momcReceivedTarget: (NSNotification *) notification
{
    if (nil != mMomcTask)
    {
        [self setMomcTargetName: [notification object]];
        kill ([mMomcTask processIdentifier], SIGUSR1);
    }
}

- (void) momcTaskEnded: (NSNotification *) notification
{
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSTaskDidTerminateNotification 
                                                  object: mMomcTask];
    if (0 == [mMomcTask terminationStatus])
    {
        [self setMomcTask: nil];
        [self importModelAtPath: mMomcTargetName];
    }
    else
    {
        NSData* content = [[[mMomcTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        NSString* contentString = [[[NSString alloc] initWithData: content encoding: NSUTF8StringEncoding] autorelease];
        [mController logAppend: contentString];
        NSAlert* alert = [NSAlert alertWithMessageText: @"Error running momc" defaultButton: @"OK" 
                                       alternateButton: nil otherButton: nil 
                             informativeTextWithFormat: @"There was an error running the data model compiler. Please check the log."];
        [alert beginSheetModalForWindow: mMainWindow modalDelegate: nil didEndSelector: NULL contextInfo: NULL];
        [self setMomcTask: nil];
    }
}

@end


@implementation ImportController (IBActions)

- (IBAction) dryRun: (id) sender
{
    if ([mImportPanel makeFirstResponder: nil])
    {
        [mController->mLogWindow makeKeyAndOrderFront: nil];
        NSArray* entities = [mImportArrayController content];
        entities = [entities filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"shouldImport == YES"]];
        [self importEntities: entities dryRun: YES];
    }
}

- (IBAction) endImportPanel: (id) sender
{
    [mController->mInspectorTable setDataSource: mController];
    if ([mImportPanel makeFirstResponder: nil])
    {
        if (1 == [sender tag])
        {
            //OK
            BOOL conflicts = NO;
            NSArray* entities = [mImportArrayController content];
            entities = [entities filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"shouldImport == YES"]];
            TSEnumerate (currentEntity, e, [entities objectEnumerator])
            {
                if (YES == [currentEntity alreadyExists])
                {
                    conflicts = YES;
                    break;
                }
            }
            
            NSAlert* alert = nil;
            if (YES == conflicts)
            {
                //Ask for confirmation in case of a conflict
                alert = [NSAlert alertWithMessageText: @"Database warning" defaultButton: @"OK" alternateButton: @"Cancel" otherButton: nil
                            informativeTextWithFormat: @"Some of the entities already have corresponding tables in the database. Do you wish to overwrite them?"];
            }
            
            if (NO == conflicts || NSAlertDefaultReturn == [alert runModal])
            {
                //OK again
                [NSApp endSheet: mImportPanel];
                [mImportPanel orderOut: nil];
                
                [mController displayProgressPanel: @"Importing..."];            
                NSError* error = [self importEntities: entities dryRun: NO];
                [mController hideProgressPanel];
                
                if (nil != error)
                    [[NSAlert alertWithError: error] beginSheetModalForWindow: mMainWindow modalDelegate: nil didEndSelector: NULL contextInfo: NULL];
                else
                {
                    [mController reload: nil];
                }
            }
        }
        else
        {
            //Cancel
            [NSApp endSheet: mImportPanel];
            [mImportPanel orderOut: nil];
        }
    }
}

- (IBAction) changeVisibleConfiguration: (id) sender
{
	// TODO: We should gather all configurations to an array and switch between the arrays here, not create entities over and over again. User set "shouldImport" property is forgotten this way.
    NSArray* entities = nil;
    if (2 == [mConfigurationButton selectedTag])
        entities = [mManagedObjectModel entities];
    else
    {
        entities = [mManagedObjectModel entitiesForConfiguration: 
            [[mConfigurationButton selectedItem] title]];
    }
    
    NSMutableArray* content = [NSMutableArray arrayWithCapacity: [entities count]];
    
    if (nil == mSchemaName)
        [self setSchemaName: @"public"];
    
    TSEnumerate (currentEntityDesc, e, [entities objectEnumerator])
    {
        Entity* entity = [[[Entity alloc] init] autorelease];
        [entity setEntityDescription: currentEntityDesc];
        [entity setSchemaName: mSchemaName];
		[entity setShouldImport:YES];
        [content addObject: entity];
    }
    [mImportArrayController setContent: content];
}

- (IBAction) changeSchemaName: (id) sender
{    
    //Check for conflicts
    NSString* queryName = @"BXImportInsert";
    PGTSResultSet* res = nil;
    res = [mConnection executeQuery: [NSString stringWithFormat: @"DEALLOCATE \"%@\"", queryName]];
    id content = [mImportArrayController content];
 
    [content setValue: [NSNumber numberWithBool: NO] forKey: @"alreadyExists"];
    [content setValue: mSchemaName forKey: @"schemaName"];

    [mConnection beginTransaction];
    res = [mConnection executeQuery: @"CREATE TEMPORARY TABLE BXImport (relname VARCHAR (255), nspname VARCHAR (255)) ON COMMIT DROP"];
    res = [mConnection executePrepareQuery: @"INSERT INTO BXImport (relname, nspname) VALUES ($1, $2)" name: queryName];
    TSEnumerate (currentEntity, e, [content objectEnumerator])
        res = [mConnection executePreparedQuery: queryName parameters: [[currentEntity entityDescription] name], [currentEntity schemaName]];
    res = [mConnection executeQuery: @"SELECT c.oid, c.relname, n.nspname FROM pg_class c INNER JOIN pg_namespace n "
        " ON (c.relnamespace = n.oid) INNER JOIN BXImport i ON (i.relname = c.relname AND i.nspname = n.nspname);"];
    [mConnection rollbackTransaction];
    
    //Mark the conflicting entities
    NSArray* keys = [content valueForKeyPath: @"entityDescription.name"];
    NSDictionary* contentDict = [NSDictionary dictionaryWithObjects: content forKeys: keys];
    while ([res advanceRow])
    {
        Entity* entity = [contentDict objectForKey: [res valueForKey: @"relname"]];
        if (nil != entity)
        {
            [entity setAlreadyExists: YES];
            [entity setIdentifier: [res valueForKey: @"oid"]];
        }
    }            
}

@end


@implementation ImportController (InspectorDataSource)

- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification
{
    NSArray* arrangedObjects = [mImportArrayController arrangedObjects];
    NSIndexSet* selectedIndexes = [mEntityTable selectedRowIndexes];
    for (unsigned int i = [selectedIndexes firstIndex]; i < NSNotFound; i = [selectedIndexes indexGreaterThanIndex: i])
    {
        NSColor* textColor = nil;
        if ([[arrangedObjects objectAtIndex: i] alreadyExists])
            textColor = [NSColor redColor];
        else
            textColor = [NSColor whiteColor];
    }
}

- (int) numberOfRowsInTableView: (NSTableView *) aTableView
{
    int count = 0;
    id selection = [mImportArrayController selectedObjects];
    if (0 < [selection count])
    {
        Entity* selectedEntity = [selection objectAtIndex: 0];
        count = [[[selectedEntity entityDescription] attributesByName] count];
    }
    return count;
}

- (id) tableView: (NSTableView *) aTableView objectValueForTableColumn: (NSTableColumn *) aTableColumn row: (int) rowIndex
{
    id selection = [mImportArrayController selectedObjects];
    NSArray* attrs = [[[[selection objectAtIndex: 0] entityDescription] attributesByName] allValues];
    id attribute = [attrs objectAtIndex: rowIndex];
    id retval = nil;
    
    if (mController->mNameColumn == aTableColumn)
        retval = [attribute name];
    else if (mController->mTypeColumn == aTableColumn)
        retval = [mEntityConverter nameForAttributeType: [attribute attributeType]];
    
    return retval;
}

- (void) tableViewSelectionDidChange: (NSNotification *) aNotification
{
    [mController->mInspectorTable reloadData];
}

@end
