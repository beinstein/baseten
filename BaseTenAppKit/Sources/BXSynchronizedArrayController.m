//
// BXSynchronizedArrayController.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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

#import "BXSynchronizedArrayController.h"
#import "NSController+BXAppKitAdditions.h"
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseAdditions.h>

#define LOG_POSITION() fprintf( stderr, "Now at %s:%d\n", __FILE__, __LINE__ )

//FIXME: Handle locks


@implementation BXSynchronizedArrayController

- (id) initWithContent: (id) content
{
    if ((self = [super initWithContent: content]))
    {
        [self setAutomaticallyPreparesContent: NO];
        [self setEditable: YES];
        mFetchesOnAwake = YES;
        mChanging = NO;
    }
    return self;
}

- (void) awakeFromNib
{
    NSError* error = nil;
    if (nil == mEntityDescription)
        [self setEntityDescription: [databaseContext entityForTable: mTableName inSchema: mSchemaName error: &error]];
    
    if (nil != error)
        [self BXHandleError: error];
    else
    {
        //Set the custom class name.
        if (nil != mDBObjectClassName)
            [mEntityDescription setDatabaseObjectClass: NSClassFromString (mDBObjectClassName)];    
        
        NSWindow* aWindow = [self BXWindow];
        [databaseContext setUndoManager: [aWindow undoManager]];
        
        if (YES == mFetchesOnAwake)
        {
            [aWindow makeKeyAndOrderFront: nil];
            [self fetch: nil];
        }
    }
    [super awakeFromNib];
}

- (BXDatabaseContext *) BXDatabaseContext
{
    return databaseContext;
}

- (NSWindow *) BXWindow
{
    return window;
}

- (BOOL) fetchObjectsMerging: (BOOL) merge error: (NSError **) error
{    
    BOOL rval = NO;
    NSArray* result = [databaseContext executeFetchForEntity: mEntityDescription withPredicate: [self fetchPredicate] error: error];
    if (nil != result)
    {
        rval = YES;
        if (NO == merge)
        {
            //Do not really remove, since we do not want to affect the database
            [super removeObjects: [self arrangedObjects]];
            [self addObjects: result];
        }
        else
        {
            NSArray* ids = [[self arrangedObjects] valueForKey: @"objectID"];
            TSEnumerate (currentObject, e, [result objectEnumerator])
            {
                if (NO == [ids containsObject: [currentObject objectID]])
                    [self addObject: currentObject];
            }
        }        
    }
    return rval;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [databaseContext release];
    [mEntityDescription release];
    [super dealloc];
}

- (void) BXAddedObjects: (NSNotification *) notification
{
    if (NO == mChanging)
    {
        NSError* error = nil;
        NSArray* ids = [[notification userInfo] valueForKey: kBXObjectIDsKey];
        NSSet* result = [databaseContext objectsWithIDs: ids error: &error];
        if (nil != error)
            [self BXHandleError: error];
        else
        {
            id content = [self content];
            TSEnumerate (currentObject, e, [[result allObjects] objectEnumerator])
            {
                if (NO == [content containsObject: currentObject])
                    [self addObject: currentObject];
            }
        }
    }
}

- (void) BXDeletedObjects: (NSNotification *) notification
{
    NSArray* objects = [[notification userInfo] valueForKey: kBXObjectsKey];
    [self removeObjects: objects];
}

- (BXEntityDescription *) entityDescription
{
    return mEntityDescription;
}

- (void) setEntityDescription: (BXEntityDescription *) desc
{
    if (desc != mEntityDescription)
    {
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver: self];
        [mEntityDescription release];
        
        mEntityDescription = desc;
        if (nil != mEntityDescription)
        {
            [mEntityDescription retain];
            [nc addObserver: self selector: @selector (BXAddedObjects:)
                       name: kBXInsertNotification object: mEntityDescription];
            [nc addObserver: self selector: @selector (BXDeletedObjects:)
                       name: kBXDeleteNotification object: mEntityDescription];
        }
    }
}

- (BXDatabaseContext *) databaseContext
{
    return databaseContext;
}

- (void) setDatabaseContext: (BXDatabaseContext *) ctx
{
    if (ctx != databaseContext)
    {
        [databaseContext release];
        databaseContext = ctx;
		
		if (nil != databaseContext)
		{
            [databaseContext retain];
            
            NSError* error = nil;
            
            //Also set the entity description, since the database URI has changed.
            BXEntityDescription* entityDescription = [databaseContext entityForTable: [self tableName] 
                                                                            inSchema: [self schemaName]
                                                                               error: &error];
            if (nil != error)
                [self BXHandleError: error];
            else
            {
                [entityDescription setDatabaseObjectClass: NSClassFromString ([self databaseObjectClassName])];
                
                [self setEntityDescription: entityDescription];
            }
		}
    }
}

- (BOOL) fetchesOnAwake
{
    return mFetchesOnAwake;
}

- (void) setFetchesOnAwake: (BOOL) aBool
{
    mFetchesOnAwake = aBool;
}

- (void) objectDidBeginEditing: (id) editor
{
    [self BXLockKey: nil status: kBXObjectLockedStatus editor: editor];
    [super objectDidBeginEditing: editor];
}

- (void) objectDidEndEditing: (id) editor
{
    [super objectDidEndEditing: editor];
    [self BXUnlockKey: nil editor: editor];
}

- (NSString *) schemaName
{
    return mSchemaName; 
}

- (void) setSchemaName: (NSString *) aSchemaName
{
    if (mSchemaName != aSchemaName) {
        [mSchemaName release];
        mSchemaName = [aSchemaName retain];
    }
}

- (NSString *) tableName
{
    return mTableName; 
}

- (void) setTableName: (NSString *) aTableName
{
    if (mTableName != aTableName) {
        [mTableName release];
        mTableName = [aTableName retain];
    }
}

- (NSString *) databaseObjectClassName
{
    return mDBObjectClassName; 
}

- (void) setDatabaseObjectClassName: (NSString *) aDBObjectClassName
{
    if (mDBObjectClassName != aDBObjectClassName) {
        [mDBObjectClassName release];
        mDBObjectClassName = [aDBObjectClassName retain];
    }
}

@end


@implementation BXSynchronizedArrayController (OverridenMethods)

- (BOOL) isEditable
{
    BOOL rval = [super isEditable];
#if 0
    if (YES == rval)
    {
        rval = [[[self selection] status] ];
    }
#endif
    return rval;
}

- (void) fetch: (id) sender
{
    NSError* error = nil;
    [self fetchObjectsMerging: YES error: &error];
    if (nil != error)
        [self BXHandleError: error];
}

- (BOOL) fetchWithRequest: (NSFetchRequest *) fetchRequest merge: (BOOL) merge error: (NSError **) error
{
    return [self fetchObjectsMerging: merge error: error];
}

- (id) newObject
{
    mChanging = YES;
    NSError* error = nil;
    id object = [databaseContext createObjectForEntity: mEntityDescription
                                       withFieldValues: nil error: &error];
    if (nil != error)
        [self BXHandleError: error];
    else
    {    
        //The returned object should have retain count of 1
        [object retain];
    }
    mChanging = NO;
    return object;
}

- (void) removeObject: (id) object
{
    NSError* error = nil;
    [databaseContext executeDeleteObject: object error: &error];
    if (nil != error)
        [self BXHandleError: error];
    else
        [super removeObject: object];
}

- (void) remove: (id) sender
{
    TSEnumerate (currentObject, e, [[self selectedObjects] objectEnumerator])
        [self removeObject: currentObject];
}

@end


@implementation BXSynchronizedArrayController (NSCoding)

- (void) encodeWithCoder: (NSCoder *) encoder
{
    [super encodeWithCoder: encoder];
    [encoder encodeBool: mFetchesOnAwake forKey: @"fetchesOnAwake"];
    
    [encoder encodeObject: mTableName forKey: @"tableName"];
    [encoder encodeObject: mSchemaName forKey: @"schemaName"];
    [encoder encodeObject: mDBObjectClassName forKey: @"DBObjectClassName"];
}

- (id) initWithCoder: (NSCoder *) decoder
{
    if ((self = [super initWithCoder: decoder]))
    {
        [self setAutomaticallyPreparesContent: NO];
        [self setEditable: YES];
        [self setFetchesOnAwake: [decoder decodeBoolForKey: @"fetchesOnAwake"]];
        
        [self setTableName:  [decoder decodeObjectForKey: @"tableName"]];
        [self setSchemaName: [decoder decodeObjectForKey: @"schemaName"]];
        [self setDatabaseObjectClassName: [decoder decodeObjectForKey: @"DBObjectClassName"]];
    }
    return self;
}

@end
