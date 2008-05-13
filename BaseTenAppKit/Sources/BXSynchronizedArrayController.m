//
// BXSynchronizedArrayController.m
// BaseTen
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

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseAdditions.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXContainerProxy.h>
#import <BaseTen/BXSetRelationProxy.h>
#import <BaseTen/BXRelationshipDescriptionPrivate.h>
#import <BaseTen/BXForeignKey.h>
#import <Log4Cocoa/Log4Cocoa.h>
#import "BXSynchronizedArrayController.h"
#import "NSController+BXAppKitAdditions.h"
#import "BXObjectStatusToColorTransformer.h"
#import "BXObjectStatusToEditableTransformer.h"


#define LOG_POSITION() fprintf( stderr, "Now at %s:%d\n", __FILE__, __LINE__ )

//FIXME: Handle locks


/**
 * An NSArrayController subclass for use with BaseTen.
 * A BXSynchronizedArrayController updates its contents automatically based on notifications received 
 * from a database context. In order to function, its databaseContext outlet needs to be connected. 
 * It may also fetch objects when the context connects. However, this option should not be enabled 
 * if the controller's contents are bound to a relationship in a database object.
 * \ingroup BaseTenAppKit
 */
@implementation BXSynchronizedArrayController

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (NO == tooLate)
	{
		tooLate = YES;
        
        // Register the transformers with the names that we refer to them with
        BXObjectStatusToColorTransformer* transformer = [[BXObjectStatusToColorTransformer alloc] init];        
        [NSValueTransformer setValueTransformer: transformer
                                        forName: @"BXObjectStatusToColorTransformer"];
        [transformer release];
        transformer = [[BXObjectStatusToEditableTransformer alloc] init];
        [NSValueTransformer setValueTransformer: transformer
                                        forName: @"BXObjectStatusToEditableTransformer"];
        [transformer release];
		
		[self exposeBinding: @"databaseContext"];
		[self exposeBinding: @"modalWindow"];
        
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
		mShouldAddToContent = YES;
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
    return modalWindow;
}

- (void) dealloc
{
    [databaseContext release];
	[mSchemaName release];
	[mTableName release];
	[mDBObjectClassName release];
	[mBXContent release];
    [super dealloc];
}

/**
 * The entity used with this array controller.
 */
- (BXEntityDescription *) entityDescription
{
    return mEntityDescription;
}

/**
 * Set the entity used with this array controller.
 */
- (void) setEntityDescription: (BXEntityDescription *) desc
{
	mEntityDescription = desc;
}

- (BXDatabaseContext *) databaseContext
{
    return databaseContext;
}

/**
 * Set the database context.
 * \internal
 * \see #setFetchesOnAwake:
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
 * Whether this controller fetches on connect.
 * \note Controllers bound to an automatically-fetching controller should not fetch on connect.
 * \internal
 * \see #setDatabaseContext:
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

/**
 * Database schema name for this controller.
 */
- (NSString *) schemaName
{
    return mSchemaName; 
}

/**
 * Set the database schema name for this controller.
 */
- (void) setSchemaName: (NSString *) aSchemaName
{
    if (mSchemaName != aSchemaName) 
	{
        [mSchemaName release];
        mSchemaName = [aSchemaName retain];
    }
}

/**
 * Database table name for this controller.
 */
- (NSString *) tableName
{
    return mTableName; 
}

/**
 * Set the database table name for this controller.
 */
- (void) setTableName: (NSString *) aTableName
{
    if (mTableName != aTableName) 
	{
        [mTableName release];
        mTableName = [aTableName retain];
    }
}

/**
 * Database object class name for this controller.
 * When setting the database context, this will be changed into a Class.
 */
- (NSString *) databaseObjectClassName
{
    return mDBObjectClassName; 
}

/**
 * Set the database object class name for this controller.
 */
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

- (id) createObject: (NSError **) outError
{
	log4AssertValueReturn (NULL != outError, nil, @"Expected outError not to be NULL.");
	NSDictionary* fieldValues = [self valuesForBoundRelationship];
	mShouldAddToContent = (nil == fieldValues);
	return [databaseContext createObjectForEntity: mEntityDescription
								  withFieldValues: fieldValues error: outError];
}

- (NSDictionary *) valuesForBoundRelationship
{
	NSDictionary* retval = nil;
	if ([mContentBindingKey isEqualToString: @"contentSet"])
	{
		//We only check contentSet, because relationships cannot be bound to any other key.
		NSDictionary* bindingInfo = [self infoForBinding: @"contentSet"];
		id observedObject = [bindingInfo objectForKey: NSObservedObjectKey];
		id boundObject = [observedObject valueForKeyPath: [bindingInfo objectForKey: NSObservedKeyPathKey]];
		if ([boundObject BXIsRelationshipProxy] && ![[boundObject relationship] isOptional])
		{
			retval = [[[boundObject relationship] foreignKey] srcDictionaryFor: mEntityDescription 
														   valuesFromDstObject: [boundObject owner]];
		}
	}
	return retval;
}

- (void) setContentBindingKey: (NSString *) aKey
{
	if (aKey != mContentBindingKey)
	{
		[mContentBindingKey release];
		mContentBindingKey = [aKey retain];
	}
}

@end


@implementation BXSynchronizedArrayController (OverridenMethods)

- (NSArray *) exposedBindings
{
	NSMutableArray* retval = [[[super exposedBindings] mutableCopy] autorelease];
	[retval removeObject: @"managedObjectContext"];
	return retval;
}

- (void) bind: (NSString *) binding toObject: (id) observableObject
  withKeyPath: (NSString *) keyPath options: (NSDictionary *) options
{
	if ([binding isEqualToString: @"contentSet"] || [binding isEqualToString: @"contentArray"])
		[self setContentBindingKey: binding];
	[super bind: binding toObject: observableObject withKeyPath: keyPath options: options];
}

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
	id object = [self createObject: &error];
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
	if (mShouldAddToContent && mContentBindingKey && ![self BXContent])
	{
		//Super's implementation selects inserted objects.
		[super insertObject: object atArrangedObjectIndex: index];
	}
	else if ([self selectsInsertedObjects])
	{
		//Don't invoke super's implementation since it replaces BXContent.
		//-newObject creates the row already.
		[self setSelectedObjects: [NSArray arrayWithObject: object]];
	}
	mShouldAddToContent = YES;
	
#if 0	
	if (mShouldAddToContent && mContentBindingKey)
	{
		NSDictionary* bindingInfo = [self infoForBinding: mContentBindingKey];
		if (nil != bindingInfo)
		{
			id observedObject = [bindingInfo objectForKey: NSObservedObjectKey];
			id boundObject = [observedObject valueForKeyPath: [bindingInfo objectForKey: NSObservedKeyPathKey]];
			if ([boundObject respondsToSelector: @selector (insertObject:atIndex:)])
				[boundObject insertObject: object atIndex: index];
			else
				[boundObject addObject: object];
		}
	}
#endif	
}

- (void) removeObjectsAtArrangedObjectIndexes: (NSIndexSet *) indexes
{
    NSError* error = nil;
    NSArray* objects = [[self arrangedObjects] objectsAtIndexes: indexes];
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
	[encoder encodeObject: mContentBindingKey forKey: @"contentBindingKey"];
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
		[self setContentBindingKey: [decoder decodeObjectForKey: @"contentBindingKey"]];
        [self setDatabaseObjectClassName: [decoder decodeObjectForKey: @"DBObjectClassName"]];
    }
    return self;
}

@end
