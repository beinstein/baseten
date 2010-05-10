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
#import <BaseTen/BXEnumerate.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXContainerProxy.h>
#import <BaseTen/BXSetRelationProxy.h>
#import <BaseTen/BXRelationshipDescriptionPrivate.h>
#import <BaseTen/BXForeignKey.h>
#import <BaseTen/BXLogger.h>
#import <BaseTen/PGTSHOM.h>
#import "BXSynchronizedArrayController.h"
#import "NSController+BXAppKitAdditions.h"
#import "BXObjectStatusToColorTransformer.h"
#import "BXObjectStatusToEditableTransformer.h"


//FIXME: Handle locks


@implementation NSObject (BXSynchronizedArrayControllerAdditions)
- (BOOL) BXIsRelationshipProxy
{
	return NO;
}
@end


@implementation NSProxy (BXSynchronizedArrayControllerAdditions)
- (BOOL) BXIsRelationshipProxy
{
	return NO;
}
@end


@implementation BXSetRelationProxy (BXSynchronizedArrayControllerAdditions)
- (BOOL) BXIsRelationshipProxy
{
	return YES;
}
@end


/**
 * \brief An NSArrayController subclass for use with BaseTen.
 *
 * A BXSynchronizedArrayController updates its contents automatically based on notifications received 
 * from a database context. In order to function, its databaseContext outlet needs to be connected. 
 * It may also fetch objects when the context connects. However, this option should not be enabled 
 * if the controller's contents are bound to a relationship in a database object.
 * \ingroup baseten_appkit
 */
@implementation BXSynchronizedArrayController
+ (void) initialize
{
	static BOOL tooLate = NO;
	if (NO == tooLate)
	{
		tooLate = YES;
        
        // Register the transformers with the names that we refer to them with
        BXObjectStatusToColorTransformer* transformer = [[[BXObjectStatusToColorTransformer alloc] init] autorelease];
        [NSValueTransformer setValueTransformer: transformer
                                        forName: @"BXObjectStatusToColorTransformer"];
        transformer = [[[BXObjectStatusToEditableTransformer alloc] init] autorelease];
        [NSValueTransformer setValueTransformer: transformer
                                        forName: @"BXObjectStatusToEditableTransformer"];
		
		[self exposeBinding: @"databaseContext"];
		[self exposeBinding: @"modalWindow"];
		[self exposeBinding: @"selectedObjects"];
        
		[self setKeys: [NSArray arrayWithObject: @"selectedObjects"] triggerChangeNotificationsForDependentKey: @"selectedObjectIDs"];
		
		[BXDatabaseContext loadedAppKitFramework];
	}
}

- (id) initWithContent: (id) content
{
    if ((self = [super initWithContent: content]))
    {
        [self setAutomaticallyPreparesContent: NO];
        [self setEditable: YES];
        mFetchesAutomatically = NO;
        mChanging = NO;
		mShouldAddToContent = YES;
		mLocksRowsOnBeginEditing = YES;
    }
    return self;
}

- (void) awakeFromNib
{
	{
		BXDatabaseContext* ctx = databaseContext;
		databaseContext = nil;
		[self setDatabaseContext: ctx];
	}
	
	NSWindow* aWindow = [self BXWindow];
	[databaseContext setUndoManager: [aWindow undoManager]];        

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
 * \brief The entity used with this array controller.
 */
- (BXEntityDescription *) entityDescription
{
    return mEntityDescription;
}

/**
 * \brief Set the entity used with this array controller.
 */
- (void) setEntityDescription: (BXEntityDescription *) desc
{
	mEntityDescription = desc;
}

/**
 * \brief The array controller's database context.
 */
- (BXDatabaseContext *) databaseContext
{
    return databaseContext;
}

- (void) prepareEntity
{
	BXAssertVoidReturn (databaseContext, @"Expected databaseContext not to be nil. Was it set or bound in Interface Builder?");
	
	[self setEntityDescription: nil];
	BXDatabaseObjectModel *objectModel = [databaseContext databaseObjectModel];
	BXEntityDescription* entityDescription = [objectModel entityForTable: [self tableName] inSchema: [self schemaName]];

	if (entityDescription)
	{
		[entityDescription setDatabaseObjectClass: NSClassFromString ([self databaseObjectClassName])];                
		[self setEntityDescription: entityDescription];
	}
	else
	{
		[self BXHandleError: [BXDatabaseObjectModel errorForMissingEntity: [self tableName] inSchema: [self schemaName]]];
	}
}

/**
 * \brief Set the database context.
 * \see #setFetchesAutomatically:
 */
- (void) setDatabaseContext: (BXDatabaseContext *) ctx
{
    if (ctx != databaseContext)
    {
		NSNotificationCenter* nc = [ctx notificationCenter];
		//databaseContext may be nil here since we don't observe multiple contexts.
		[nc removeObserver: self name: kBXConnectionSuccessfulNotification object: databaseContext];
		[nc removeObserver: self name: kBXGotDatabaseURINotification object: databaseContext];
		
        [databaseContext release];
        databaseContext = [ctx retain];
		
		if (databaseContext)
		{
			[self setEntityDescription: nil];
			[[databaseContext notificationCenter] addObserver: self selector: @selector (endConnecting:) name: kBXConnectionSuccessfulNotification object: databaseContext];
			
			if (mFetchesAutomatically && (mTableName || mEntityDescription) && [databaseContext isConnected])
				[self fetch: nil];
		}
    }
}

/**
 * \brief Whether this controller fetches automatically.
 */
- (BOOL) fetchesAutomatically
{
    return mFetchesAutomatically;
}

- (BOOL) fetchesOnConnect
{
    return [self fetchesAutomatically];
}

/**
 * \brief Set whether this controller fetches automatically.
 *
 * This causes the content to be fetched automatically
 * when the array controller receives a connection notification or
 * the array controller's database context is set and is already 
 * connected.
 * \note Controllers the content of which is bound to other 
 *       BXSynchronizedArrayControllers should not fetch on connect.
 * \see #setDatabaseContext:
 */
- (void) setFetchesAutomatically: (BOOL) aBool
{
	if (mFetchesAutomatically != aBool)
	{
		mFetchesAutomatically = aBool;
		if (nil != databaseContext)
		{
			NSNotificationCenter* nc = [databaseContext notificationCenter];
			if (mFetchesAutomatically)
				[nc addObserver: self selector: @selector (endConnecting:) name: kBXConnectionSuccessfulNotification object: databaseContext];
			else
				[nc removeObserver: self name: kBXConnectionSuccessfulNotification object: databaseContext];
		}
	}
}

- (void) setFetchesOnConnect: (BOOL) aBool
{
	[self setFetchesAutomatically: aBool];
}

/**
 * \brief Whether the receiver begins a transaction for each editing session.
 */
- (BOOL) locksRowsOnBeginEditing
{
	return mLocksRowsOnBeginEditing;
}

/**
 * \brief Set whether the receiver begins a transaction for each editing session.
 *
 * Sets whether the receiver asks its database context to begin a transaction
 * to lock the corresponding row when each editing session begins. Regardless of
 * the context setting for sending lock notifications, other BaseTen clients will
 * always be notified. When editing ends, the transaction will end as well. This 
 * is determined from calls to -objectDidBeginEditing: and -objectDidEndEditing: 
 * declared in NSEditor protocol. The default is YES.
 * \see BXDatabaseContext::setSendsLockQueries:
 */
- (void) setLocksRowsOnBeginEditing: (BOOL) aBool
{
	mLocksRowsOnBeginEditing = aBool;
}

/**
 * \name Methods used by the IB plugin
 * \brief The controller will try to get an entity description when its database context
 *        based on these properties. This will occur when the context gets set and when 
 *        the context connects. If a class name has also been set, the controller will
 *        call NSClassFromString and set the entity's corresponding property.
 */
//@{
/**
 * \brief Database schema name for this controller.
 */
- (NSString *) schemaName
{
    return mSchemaName; 
}

/**
 * \brief Set the database schema name for this controller.
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
 * \brief Database table name for this controller.
 */
- (NSString *) tableName
{
    return mTableName; 
}

/**
 * \brief Set the database table name for this controller.
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
 * \brief Database object class name for this controller.
 */
- (NSString *) databaseObjectClassName
{
    return mDBObjectClassName; 
}

/**
 * \brief Set the database object class name for this controller.
 */
- (void) setDatabaseObjectClassName: (NSString *) aDBObjectClassName
{
    if (mDBObjectClassName != aDBObjectClassName) 
	{
        [mDBObjectClassName release];
        mDBObjectClassName = [aDBObjectClassName retain];
    }
}
//@}

- (void) endConnecting: (NSNotification *) notification
{
	if (! mEntityDescription)
		[self prepareEntity];
	
	if (mFetchesAutomatically)
		[self fetch: nil];
}

//Patch by henning & #macdev 2008-01-30
static BOOL 
IsKindOfClass (id self, Class class) 
{	
	if (self == nil) 
		return NO; 
	else if ([self class] == class) 
		return YES; 
	else 
		return IsKindOfClass ([self superclass], class);
}
//End patch

- (void) setBXContent: (id) anObject
{
    BXAssertLog (nil == mBXContent || IsKindOfClass (anObject, [BXContainerProxy class]),
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

/**
 * \brief Create a new object.
 *
 * Calls
 * -[BXDatabaseContext createObjectForEntity:withFieldValues:error:].
 * If the receiver's contentSet is bound to another BXSynchronizedArrayController using
 * a key that refers to a to-many relationship, the created object's foreign key values
 * will be set accordingly.
 * \param outError Error returned by the database. If NULL is passed and an error occurs,
 *                 BXDatabaseContext will raise an exception by default.
 * \return An autoreleased BXDatabaseObject.
 * \see #newObject
 */
- (id) createObject: (NSError **) outError
{
	if (! mEntityDescription)
		[self prepareEntity];
	
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
		if ([boundObject BXIsRelationshipProxy])
		{
            //FIXME: many-to-many relationships aren't handled.
			BXRelationshipDescription* rel = [boundObject relationship];
			BXRelationshipDescription* inverse = [rel inverseRelationship];
			if (! [inverse isToMany])
			{
				retval = [NSDictionary dictionaryWithObject: [boundObject owner] forKey: inverse];
			}
		}
	}
	return retval;
}

- (NSString *) contentBindingKey
{
	return mContentBindingKey;
}

- (void) setContentBindingKey: (NSString *) aKey
{
	if (aKey != mContentBindingKey)
	{
		[mContentBindingKey release];
		mContentBindingKey = [aKey retain];
		
		if ([aKey length]) [self setFetchesAutomatically: NO];
	}
}

/**
 * \brief The Object IDs of the selected objects.
 */
- (NSArray *) selectedObjectIDs
{
	return (id) [[[self selectedObjects] PGTSCollect] objectID];
}


#pragma mark OverriddenMethods
/**
 * \name Overridden methods
 * \brief Methods changed from NSArrayController's implementation.
 */
//@{
/**
 * \brief Exposed bindings
 *
 * managedObjectContext is removed from bindings exposed by the superclass.
 */
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

- (void) unbind: (NSString *) binding
{
	[super unbind: binding];
	if ([binding isEqualToString: @"contentSet"] || [binding isEqualToString: @"contentArray"])
		[self setContentBindingKey: nil];
}

- (void) objectDidBeginEditing: (id) editor
{
	if (mLocksRowsOnBeginEditing)
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
}

- (void) objectDidEndEditing: (id) editor
{
	if (mLocksRowsOnBeginEditing)
	{
		//See -objectDidBeginEditing:.
		if (self != editor)
		{
			[super objectDidEndEditing: editor];
			[self BXUnlockKey: nil editor: editor];
		}
	}
}

#if 0
/** \cond */
- (BOOL) isEditable
{
    BOOL retval = [super isEditable];
    if (YES == retval)
    {
        retval = [[[self selection] status] ];
    }
    return retval;
}
/** \endcond */
#endif

/**
 * \brief Perform a fetch.
 *
 * Calls -fetchWithRequest:merge:error:. If an error occurs, an alert sheet or panel is displayed.
 * \param sender Ignored.
 */
- (void) fetch: (id) sender
{
    NSError* error = nil;
	[self fetchWithRequest: nil merge: NO error: &error];
    if (nil != error)
        [self BXHandleError: error];
}

/**
 * \brief Perform a fetch.
 *
 * Fetch objects from the database.
 * \param fetchReques Currently ignored. Pass nil.
 * \param merge Whether the content should be replaced. If the receiver already
 *              has a collection, it won't be re-fetched, because the collection's contents
 *              will be automatically updated.
 * \param error Error returned by the database. If NULL is passed and an error occurs,
 *              BXDatabaseContext will raise an exception by default.
 * \return      If the fetch was successful or it wasn't needed, the receiver will return YES.
 */
- (BOOL) fetchWithRequest: (NSFetchRequest *) fetchRequest merge: (BOOL) merge error: (NSError **) error
{
	if (! mEntityDescription)
		[self prepareEntity];
	
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

/**
 * \brief Create a new object.
 *
 * Calls #createObject:, which in turn calls 
 * -[BXDatabaseContext createObjectForEntity:withFieldValues:error:].
 * If an error occurs, an alert sheet or panel will be displayed.
 * If the receiver's contentSet is bound to another BXSynchronizedArrayController using
 * a key that refers to a to-many relationship, the created object's foreign key values
 * will be set accordingly. 
 * \return A retained BXDatabaseObject.
 */
- (id) newObject
{
    mChanging = YES;
    NSError* error = nil;
	id object = [self createObject: &error];
    if (nil != error)
        [self BXHandleError: error];
    else
    {    
        //The returned object should have retain count of 1.
        [object retain];
    }
    mChanging = NO;
    return object;
}

- (void) insertObject: (id) object atArrangedObjectIndex: (NSUInteger) index
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

/**
 * \brief Delete objects at specified indices.
 *
 * Deletes specified rows from the database. The objects will be marked deleted.
 * If an error occurs, an alert sheet or panel will be displayed.
 */
- (void) removeObjectsAtArrangedObjectIndexes: (NSIndexSet *) indexes
{
	if (0 < [indexes count])
	{
		NSError* error = nil;
		NSArray* objects = [[self arrangedObjects] objectsAtIndexes: indexes];
		BXEntityDescription* entity = [(BXDatabaseObject *) [objects lastObject] entity];
		ExpectV (entity);
		
		NSMutableArray* predicates = [NSMutableArray arrayWithCapacity: [objects count]];
		BXEnumerate (currentObject, e, [objects objectEnumerator])
		{
			BXAssertVoidReturn ([(BXDatabaseObject *) currentObject entity] == entity, 
								@"Expected entities to match. (%@, %@)", entity, [currentObject entityDescription]);
			[predicates addObject: [[(BXDatabaseObject *) currentObject objectID] predicate]];
		}
		
		NSPredicate* predicate = [NSCompoundPredicate orPredicateWithSubpredicates: predicates];
		[databaseContext executeDeleteFromEntity: entity withPredicate: predicate error: &error];
		if (nil != error)
			[self BXHandleError: error];
	}
}

- (NSString *) entityName
{
	return nil;
}

- (void) setEntityName: (NSString *) name
{
}

- (NSManagedObjectContext *) managedObjectContext
{
	return nil;
}

- (void) setManagedObjectContext: (NSManagedObjectContext*) ctx
{
}

- (BOOL) usesLazyFetching
{
	return NO;
}

- (void) setUsesLazyFetching: (BOOL) enabled
{
}

- (Class) objectClass
{
	return [mEntityDescription databaseObjectClass];
}

- (void) setObjectClass: (Class) cls
{
	if (! mEntityDescription)
		[self prepareEntity];
	
	[mEntityDescription setDatabaseObjectClass: cls];
}
//@}
@end


@implementation BXSynchronizedArrayController (NSCoding)
- (void) encodeWithCoder: (NSCoder *) encoder
{
	//Don't change fetchesOnConnect in strings, or users' nibs stop working.
	
    [super encodeWithCoder: encoder];
    [encoder encodeBool: mFetchesAutomatically forKey: @"fetchesOnConnect"];
	[encoder encodeBool: mLocksRowsOnBeginEditing forKey: @"locksRowsOnBeginEditing"];
    
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
		
		//Some reasonable default values for booleans to make existing nibs work.
		
		BOOL fetchOnConnect = NO;
		if ([decoder containsValueForKey: @"fetchesOnConnect"])
			fetchOnConnect = [decoder decodeBoolForKey: @"fetchesOnConnect"];
        [self setFetchesAutomatically: fetchOnConnect];
		
		BOOL lockOnBeginEditing = YES;
		if ([decoder containsValueForKey: @"locksRowsOnBeginEditing"])
			lockOnBeginEditing = [decoder decodeBoolForKey: @"locksRowsOnBeginEditing"];
		[self setLocksRowsOnBeginEditing: lockOnBeginEditing];
        
        [self setTableName:  [decoder decodeObjectForKey: @"tableName"]];
        [self setSchemaName: [decoder decodeObjectForKey: @"schemaName"]];
		[self setContentBindingKey: [decoder decodeObjectForKey: @"contentBindingKey"]];
        [self setDatabaseObjectClassName: [decoder decodeObjectForKey: @"DBObjectClassName"]];
    }
    return self;
}
@end
