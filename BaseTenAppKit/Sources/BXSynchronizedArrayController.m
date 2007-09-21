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

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseAdditions.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXContainerProxy.h>
#import <Log4Cocoa/Log4Cocoa.h>
#import "BXSynchronizedArrayController.h"
#import "NSController+BXAppKitAdditions.h"


#define LOG_POSITION() fprintf( stderr, "Now at %s:%d\n", __FILE__, __LINE__ )

//FIXME: Handle locks


/**
 * An NSArrayController subclass for use with BaseTen.
 */
@implementation BXSynchronizedArrayController

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (NO == tooLate)
	{
		tooLate = YES;
		[BXDatabaseContext loadedAppKitFramework];
	}
}

- (id) initWithContent: (id) content
{
    if ((self = [super initWithContent: content]))
    {
        [self setAutomaticallyPreparesContent: NO];
        [self setEditable: YES];
        mFetchesOnConnect = NO;
        mChanging = NO;
    }
    return self;
}

- (void) awakeFromNib
{
    NSError* error = nil;
	[databaseContext retain];
	
    if (nil == mEntityDescription && nil != mTableName)
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

- (void) dealloc
{
    [databaseContext release];
    [mEntityDescription release];
	[mSchemaName release];
	[mTableName release];
	[mDBObjectClassName release];
	[mBXContent release];
    [super dealloc];
}

- (BXEntityDescription *) entityDescription
{
    return mEntityDescription;
}

- (void) setEntityDescription: (BXEntityDescription *) desc
{
	mEntityDescription = desc;
}

- (BXDatabaseContext *) databaseContext
{
    return databaseContext;
}

/**
 * \internal
 * \see setFetchesOnAwake:
 */
- (void) setDatabaseContext: (BXDatabaseContext *) ctx
{
    if (ctx != databaseContext)
    {
		NSNotificationCenter* nc = [ctx notificationCenter];
		//databaseContext may be nil here since we don't observe multiple contexts.
		[nc removeObserver: self name: kBXConnectionSuccessfulNotification object: databaseContext];
		
        [databaseContext release];
        databaseContext = ctx;
		
		if (nil != databaseContext)
		{
            nc = [databaseContext notificationCenter];
            [databaseContext retain];
			if (mFetchesOnConnect)
				[nc addObserver: self selector: @selector (endConnecting:) name: kBXConnectionSuccessfulNotification object: databaseContext];
            
            //Also set the entity description, since the database URI has changed.
			if (nil != [self tableName])
			{
				NSError* error = nil;
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
}

- (BOOL) fetchesOnConnect
{
    return mFetchesOnConnect;
}

/**
 * \internal
 * \see setDatabaseContext:
 */
- (void) setFetchesOnConnect: (BOOL) aBool
{
	if (mFetchesOnConnect != aBool)
	{
		mFetchesOnConnect = aBool;
		if (nil != databaseContext)
		{
			NSNotificationCenter* nc = [databaseContext notificationCenter];
			if (YES == mFetchesOnConnect)
				[nc addObserver: self selector: @selector (endConnecting:) name: kBXConnectionSuccessfulNotification object: databaseContext];
			else
				[nc removeObserver: self name: kBXConnectionSuccessfulNotification object: databaseContext];
		}
	}
}

- (void) objectDidBeginEditing: (id) editor
{
	//This is a bit bad. Since we have bound one of our own attributes to 
	//one of our bindings, -commitEditing might get called recursively ad infinitum.
	//We prevent this by not starting to edit in this object; it doesn't happen
	//normally in 10.4, either.
	if (self != editor)
	{
		[self BXLockKey: nil status: kBXObjectLockedStatus editor: editor];
		[super objectDidBeginEditing: editor];
	}
}

- (void) objectDidEndEditing: (id) editor
{
	//See -objectDidBeginEditing:.
	if (self != editor)
	{
		[super objectDidEndEditing: editor];
		[self BXUnlockKey: nil editor: editor];
	}
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

- (NSString *) tableName
{
    return mTableName; 
}

- (void) setTableName: (NSString *) aTableName
{
    if (mTableName != aTableName) 
	{
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
    if (mDBObjectClassName != aDBObjectClassName) 
	{
        [mDBObjectClassName release];
        mDBObjectClassName = [aDBObjectClassName retain];
    }
}

- (void) endConnecting: (NSNotification *) notification
{
	if (YES == mFetchesOnConnect)
		[self fetch: nil];
}

- (void) setBXContent: (id) anObject
{
    log4AssertLog (nil == mBXContent || [anObject isKindOfClass: [BXContainerProxy class]], 
                   @"Expected anObject to be an instance of BXContainerProxy (was: %@).", 
                   [anObject class]);
	if (mBXContent != anObject)
	{
		[mBXContent release];
		mBXContent = [anObject retain];
	}
}

- (id) BXContent
{
	return mBXContent;
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
	[self fetchWithRequest: nil merge: NO error: &error];
    if (nil != error)
        [self BXHandleError: error];
}

- (BOOL) fetchWithRequest: (NSFetchRequest *) fetchRequest merge: (BOOL) merge error: (NSError **) error
{
    BOOL retval = NO;
	if (merge && nil != [self content])
	{
		//This should happen automatically. Currently we don't have an API to refresh an
		//automatically-updated collection.
		retval = YES;
	}
	else
	{
		id result = [databaseContext executeFetchForEntity: mEntityDescription 
											 withPredicate: [self fetchPredicate]
										   returningFaults: NO
									   updateAutomatically: YES
													 error: error];

		[self setBXContent: result];
		[result setOwner: self];
		[result setKey: @"BXContent"];
		[self bind: @"contentArray" toObject: self withKeyPath: @"BXContent" options: nil];
	}
	
    return retval;
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

- (void) insertObject: (id) object atArrangedObjectIndex: (unsigned int) index
{
    //Don't invoke super's implementation since it replaces BXContent.
    //-newObject creates the row already.
}

- (void) removeObjectsAtArrangedObjectIndexes: (NSIndexSet *) indexes
{
    NSError* error = nil;
    NSArray* objects = [[self BXContent] objectsAtIndexes: indexes];
    NSMutableArray* predicates = [NSMutableArray arrayWithCapacity: [objects count]];
    TSEnumerate (currentObject, e, [objects objectEnumerator])
        [predicates addObject: [[(BXDatabaseObject *) currentObject objectID] predicate]];
    [databaseContext executeDeleteFromEntity: [self entityDescription]
                               withPredicate: [NSCompoundPredicate andPredicateWithSubpredicates: predicates]
                                       error: &error];
    if (nil != error)
        [self BXHandleError: error];
}
@end


@implementation BXSynchronizedArrayController (NSCoding)

- (void) encodeWithCoder: (NSCoder *) encoder
{
    [super encodeWithCoder: encoder];
    [encoder encodeBool: mFetchesOnConnect forKey: @"fetchesOnConnect"];
    
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
        [self setFetchesOnConnect: [decoder decodeBoolForKey: @"fetchesOnConnect"]];
        
        [self setTableName:  [decoder decodeObjectForKey: @"tableName"]];
        [self setSchemaName: [decoder decodeObjectForKey: @"schemaName"]];
        [self setDatabaseObjectClassName: [decoder decodeObjectForKey: @"DBObjectClassName"]];
    }
    return self;
}

@end
