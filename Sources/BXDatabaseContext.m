//
// BXDatabaseContext.m
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

#import <TSDataTypes/TSDataTypes.h>
#import <PGTS/PGTS.h>
#import <PGTS/PGTSFunctions.h>
#import <stdlib.h>
#import <string.h>
#import <Log4Cocoa/Log4Cocoa.h>
#import <BaseTenAppKit/BXDatabaseContextAdditions.h>

#import "BXDatabaseAdditions.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXConstants.h"
#import "BXInterface.h"
#import "BXPGInterface.h"
#import "BXDatabaseObject.h"
#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXConstants.h"
#import "BXRelationshipDescriptionProtocol.h"
#import "BXException.h"
#import "BXContainerProxy.h"
#import "BXArrayProxy.h"

#undef BXHandleError
#define BXHandleError( ERROR, LOCAL_ERROR ) \
    if ( nil != LOCAL_ERROR ) { if ( NULL != ERROR ) *(NSError **)ERROR = LOCAL_ERROR; else [self handleError: LOCAL_ERROR]; }
            


static NSMutableDictionary* gInterfaceClassSchemes = nil;


extern void BXInit ()
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        PGTSInit ();
    }
}


/** 
 * The database context. 
 * A database context connects to a given database, creates objects
 * using the rows and sends commands to the database.
 *
 * This class is not thread-safe, i.e. 
 * if methods of a BXDatabaseContext instance will be called from 
 * different threads the result is undefined and deadlocks are possible.
 */
@implementation BXDatabaseContext

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        gInterfaceClassSchemes = [[NSMutableDictionary alloc] init];

        //If this class were in a separate framework, this method should be called from the
        //framework initializer function
        [BXPGInterface initialize];
    }
}

+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

+ (BOOL) isSchemeSupported: (NSString *) scheme
{
    return (nil != [gInterfaceClassSchemes valueForKey: scheme]);
}

+ (BOOL) setInterfaceClass: (Class) aClass forScheme: (NSString *) scheme
{
    BOOL rval = NO;
    if ([aClass conformsToProtocol: @protocol (BXInterface)])
    {
        rval = YES;
        [gInterfaceClassSchemes setValue: aClass forKey: scheme];
    }
    return rval;
}

+ (Class) interfaceClassForScheme: (NSString *) scheme
{
    return [gInterfaceClassSchemes valueForKey: scheme];
}

/**
 * A convenience method.
 * \param   uri     URI of the target database
 * \return          The database context
 * \throw   NSException named kBXUnsupportedDatabaseException in case the given URI cannot be handled.
 */
+ (id) contextWithDatabaseURI: (NSURL *) uri
{
    return [[[self alloc] initWithDatabaseURI: uri] autorelease];
}

/**
 * An initializer.
 * The database URI has to be set afterwards.
 * \return          The database context
 * \throw           NSException named kBXUnsupportedDatabaseException in case the given URI cannot be handled.
 */
- (id) init
{
    return [self initWithDatabaseURI: nil];
}

/**
 * The designated initializer.
 * \param   uri     URI of the target database
 * \return          The database context
 */
- (id) initWithDatabaseURI: (NSURL *) uri
{
    if ((self = [super init]))
    {
        [self setDatabaseURI: uri];
        
        char* logEnv = getenv ("BaseTenLogQueries");
        mLogsQueries = (NULL != logEnv && strcmp ("YES", logEnv));
        mDeallocating = NO;
    }
    return self;
}

- (void) dealloc
{
    mDeallocating = YES;
    [self rollback];
    [mObjects makeObjectsPerformSelector: @selector (BXDatabaseContextWillDealloc) withObject: nil];
    
    [mDatabaseInterface release];
    [mDatabaseURI release];
    [mSeenEntities release];
    [mObjects release];
    [mModifiedObjectIDs release];
    [mUndoManager release];
	[mLazilyValidatedEntities release];
    log4Debug (@"Deallocating BXDatabaseContext");
    [super dealloc];
}

- (void) checkURIScheme: (NSURL *) url
{
    if (Nil == [[self class] interfaceClassForScheme: [url scheme]])
    {
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            self,   kBXDatabaseContextKey,
            url,    kBXURIKey,
            nil];
        @throw [NSException exceptionWithName: kBXUnsupportedDatabaseException 
                                       reason: nil
                                     userInfo: userInfo];
    }
}

/**
 * Set the database URI.
 * \param   uri     The database URI
 * \throw   NSException named kBXUnsupportedDatabaseException in case the given URI cannot be handled.
 */
- (void) setDatabaseURI: (NSURL *) uri
{
    if (uri != mDatabaseURI)
    {
        if (nil != uri)
            [self checkURIScheme: uri];
        [mDatabaseURI release];
        mDatabaseURI = [uri retain];
    }
}

/**
 * The database URI.
 */
- (NSURL *) databaseURI
{
    return mDatabaseURI;
}

- (void) connectIfNeeded: (NSError **) error
{
    NSError* localError = nil;
    if ([self checkDatabaseURI: &localError])
    {
        if (NO == [[self databaseInterface] connected])
        {
			[self lazyInit];
			[mDatabaseInterface connect: &localError];
			
			if (nil == localError) [self connectedToDatabase: &localError];
        }
    }
    BXHandleError (error, localError);
}

- (void) connectAsyncIfNeeded
{
	NSError* localError = nil;
	if ([self checkDatabaseURI: &localError])
	{
		if (NO == [[self databaseInterface] connected])
		{
			[self lazyInit];
			[mDatabaseInterface connectAsync: &localError];
		}
	}
	//FIXME: post notification in case of an error
}

- (BOOL) isConnected
{
	return [mDatabaseInterface connected];
}

- (BOOL) hasSeenEntity: (BXEntityDescription *) entity
{
    return [mSeenEntities containsObject: entity];
}

- (NSSet *) seenEntities
{
    return mSeenEntities;
}

- (void) setHasSeen: (BOOL) aBool entity: (BXEntityDescription *) anEntity
{
    [mSeenEntities addObject: anEntity];
}

/**
 * Set the query execution method.
 * When autocommit is not on, savepoints are inserted after each query
 * and undo is available. Changes do not get propagated immediately.
 * Instead, other users get information about locked rows.
 * If the context gets deallocated during a transaction, a ROLLBACK
 * is sent to the database.
 * \param   aBool   Whether or not to use autocommit
 */
- (void) setAutocommits: (BOOL) aBool
{
    [self willChangeValueForKey: @"autocommits"];
    mAutocommits = aBool;
    [mDatabaseInterface setAutocommits: aBool];
    [self didChangeValueForKey: @"autocommits"];
}

/**
 * Query execution method
 * \return          A BOOL indicating whether autocommit is in use or not.
 */
- (BOOL) autocommits
{
    BOOL rval = mAutocommits;
    if (nil != mDatabaseInterface)
        rval = [mDatabaseInterface autocommits];
    return mAutocommits;
}

- (void) BXDatabaseObjectWillDealloc: (BXDatabaseObject *) anObject
{
    [mObjects removeObjectForKey: [anObject objectID]];
}

/**
 * \internal
 * Register an object to the context
 * After fetching objects from the database, a database interface should register them with a context.
 * This enables updating the database as well as automatic synchronization, if this has been implemented
 * in the database interface class.
 * \return A boolean. NO indicates that an object was already registered.
 */
- (BOOL) registerObject: (BXDatabaseObject *) anObject
{
    BOOL rval = NO;
    BXDatabaseObjectID* objectID = [anObject objectID];
    if (nil == [mObjects objectForKey: objectID])
    {
        rval = YES;
        [mObjects setObject: anObject forKey: objectID];
    }
    return rval;
}

- (void) unregisterObject: (BXDatabaseObject *) anObject
{
    [mObjects removeObjectForKey: [anObject objectID]];
}

/**
 * A registered database object.
 * Looks up an object from the cache. The database is not queried in any case.
 * \return The cached object or nil
 */
- (BXDatabaseObject *) registeredObjectWithID: (BXDatabaseObjectID *) objectID
{
    return [mObjects objectForKey: objectID];
}

- (NSArray *) registeredObjectsWithIDs: (NSArray *) objectIDs
{
    return [self registeredObjectsWithIDs: objectIDs nullObjects: YES];
}

- (NSArray *) registeredObjectsWithIDs: (NSArray *) objectIDs nullObjects: (BOOL) returnNullObjects
{
    NSArray* rval = [mObjects objectsForKeys: objectIDs notFoundMarker: [NSNull null]];
    if (NO == returnNullObjects)
    {
        NSNull* nullObject = [NSNull null];
        NSMutableArray* objects = [NSMutableArray arrayWithCapacity: [objectIDs count]];
        TSEnumerate (currentObject, e, [rval objectEnumerator])
        {
            if (nullObject != currentObject)
                [objects addObject: currentObject];
        }
        rval = objects;
    }
    return rval;
}

/**
 * Query logging.
 * \return          A boolean indicating whether the queries 
 *                  get logged to the standard output or not.
 */
- (BOOL) logsQueries
{
    BOOL rval = mLogsQueries;
    if (nil != mDatabaseInterface)
        rval =  [mDatabaseInterface logsQueries];
    return rval;
}

/**
 * Enable or disable query logging.
 * \param   aBool       A boolean indicating whether query logging 
 *                      should be enabled or not
 */
- (void) setLogsQueries: (BOOL) aBool
{
    mLogsQueries = aBool;
    if (nil != mDatabaseInterface)
        [mDatabaseInterface setLogsQueries: aBool];
}

/**
 * The undo manager used by the context.
 * \return          The undo manager.
 */
- (NSUndoManager *) undoManager
{
    return mUndoManager;
}

/**
 * Set the undo manager used by the context.
 * Instead of creating an undo manager owned by the context, the undo invocations 
 * can be sent to a window's undo manager, for example. The change is done only if there isn't an
 * open undo group in the current undo manager.
 * \param       aManager    The supplied undo manager
 * \return                  Whether changing the undo manager was successful or not
 */
- (BOOL) setUndoManager: (NSUndoManager *) aManager
{
    BOOL rval = NO;
    if (aManager == mUndoManager)
        rval = YES;
    else if (0 == [mUndoManager groupingLevel])
    {
        rval = YES;
        [mUndoManager release];
        mUndoManager = [aManager retain];
    }
    return rval;
}

- (void) undoWithRedoInvocations: (NSArray *) invocations
{
    [[mUndoManager prepareWithInvocationTarget: self] redoInvocations: invocations];
    [mDatabaseInterface undo];
}

- (void) redoInvocations: (NSArray *) invocations
{
    [invocations makeObjectsPerformSelector: @selector (invoke)];
}

- (void) handleError: (NSError *) anError
{
    [[anError BXExceptionWithName: kBXExceptionUnhandledError] raise];
}

- (void) setModalWindow: (NSWindow *) aWindow
{
	if (aWindow != mModalWindow)
	{
		[mModalWindow release];
		mModalWindow = [aWindow retain];
	}
}

- (void) setPolicyDelegate: (id) anObject
{
	mPolicyDelegate = anObject;
}

@end


@implementation BXDatabaseContext (Queries)

/** 
 * \name Retrieving objects from the database.
 * The methods block until the query result has been retrieved.\n
 * If the method execution fails and the \c error parameter is NULL, a BXException named 
 * \c kBXExceptionUnhandledError is thrown.\n
 * If the method execution fails and the \c error parameter is not NULL, the given 
 * \c error pointer is set to the corresponding NSError object.
 */
//@{
/**
 * Fetch objects from the database.
 * Essentially calls #executeFetchForEntity:withPredicate:returningFaults:error: with \c returningFaults set to NO.
 *  
 * \param       entity          The entity from which the information is retrieved
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException with name \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and the query failed.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time.
 */
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate error: (NSError **) error
{
    return [self executeFetchForEntity: entity withPredicate: predicate returningFaults: NO error: error];
}

/**
 * Fetch objects from the database.
 * Instead of fetching the field values, the context can retrieve objects that
 * contain only the object ID. The other values get fetched on-demand.\n
 * Essentially calls #executeFetchForEntity:withPredicate:returningFaults:updateAutomatically:error: with updateAutomatically set to NO.
 *
 * \param       entity          The entity from which the information is retrieved
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       returnFaults    A boolean indicating whether faults should
 *                              be returned or not.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException with name \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and the query failed.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time.
 */
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity 
                      withPredicate: (NSPredicate *) predicate 
                    returningFaults: (BOOL) returnFaults 
                              error: (NSError **) error
{
    return [self executeFetchForEntity: entity withPredicate: predicate 
                       returningFaults: returnFaults updateAutomatically: NO error: error];
}

/**
 * Fetch objects from the database.
 * Instead of fetching all the columns, the user may supply a list of fields
 * that are excluded from the query results. The returned objects are 
 * faults. Values for the non-excluded fields are cached, though.\n
 * Essentially calls #executeFetchForEntity:withPredicate:excludingFields:updateAutomatically:error:
 * with updateAutomatically set to NO.
 *
 * \param       entity          The entity from which the information is retrieved
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       excludedFields  An NSArray containing the BXPropertyDescriptors for the columns
 *                              that should be excluded. May be nil.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException with name \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and the query failed.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time.
 */
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity 
                      withPredicate: (NSPredicate *) predicate 
                    excludingFields: (NSArray *) excludedFields 
                              error: (NSError **) error
{
    return [self executeFetchForEntity: entity withPredicate: predicate 
                       excludingFields: excludedFields updateAutomatically: NO error: error];
}

/** 
 * Fetch objects from the database.
 * The result array can be set to be updated automatically. 
 * \param       entity          The entity from which the information is retrieved
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       returnFaults    A boolean indicating whether faults should be returned or not
 * \param       shouldUpdate    A boolean indicating whether the results 
 *                              should be updated by the context or not
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException with name \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and the query failed.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time, or a subclass of NSProxy that forwards
 *                              messages to the array
 */
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
                    returningFaults: (BOOL) returnFaults updateAutomatically: (BOOL) shouldUpdate error: (NSError **) error
{
    return [self executeFetchForEntity: entity withPredicate: predicate
                       returningFaults: returnFaults excludingFields: nil
                         returnedClass: (shouldUpdate ? [BXArrayProxy class] : Nil) 
                                 error: error];
}

/**
 * Fetch objects from the database.
 * The result array can be set to be updated automatically.
 * \param       entity          The entity from which the information is retrieved
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       excludedFields  An NSArray containing the BXPropertyDescriptors for the columns
 *                              that should be excluded. May be nil.
 * \param       shouldUpdate    A boolean indicating whether the results 
 *                              should be updated by the context or not
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException with name \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and the query failed.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time, or a subclass of NSProxy that forwards
 *                              messages to the array
 */
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
                    excludingFields: (NSArray *) excludedFields updateAutomatically: (BOOL) shouldUpdate error: (NSError **) error
{
    return [self executeFetchForEntity: entity withPredicate: predicate
                       returningFaults: (0 != [excludedFields count]) excludingFields: excludedFields
                         returnedClass: (shouldUpdate ? [BXArrayProxy class] : Nil) 
                                 error: error];
}
//@}


/** \name Creating new database objects */
//@{
/**
 * Create a new database object.
 * Essentially inserts a new row into the database and retrieves it.
 * \param       entity          The target entity
 * \param       fieldValues     Initial values for fields. May be nil or left empty if
 *                              values for the primary key can be determined by the database.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \return                      A subclass of BXDatabaseObject or nil, if an error has occured
 * \throw       BXException with name \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and a database object couldn't be created.
 */
- (id) createObjectForEntity: (BXEntityDescription *) entity 
             withFieldValues: (NSDictionary *) fieldValues 
                       error: (NSError **) error
{
    NSError* localError = nil;
    BXDatabaseObject* rval = nil;
    [self connectIfNeeded: &localError];
    if (nil == localError)
    {
        //First make the object
        rval = [mDatabaseInterface createObjectForEntity: entity withFieldValues: fieldValues
                                                  class: [entity databaseObjectClass]
                                                  error: &localError];
        [rval awakeFromInsert];
        
        //Then use the values received from the database with the redo invocation
        if (nil != rval)
        {
            BXDatabaseObjectID* objectID = [rval objectID];
            [self addedObjectsToDatabase: [NSArray arrayWithObject: objectID]];
            
            if (NO == [mDatabaseInterface autocommits])
            {
                objectID = [mModifiedObjectIDs BXConditionalAdd: objectID];
                
                //For redo
                TSInvocationRecorder* recorder = [TSInvocationRecorder recorder];
                [[recorder recordWithPersistentTarget: self] createObjectForEntity: entity 
                                                                   withFieldValues: [rval cachedObjects]
                                                                             error: NULL];
                [[recorder recordWithPersistentTarget: self] addedObjectsToDatabase: [NSArray arrayWithObject: objectID]];
                
                //Undo manager does things in reverse order
                NSArray* invocations = [recorder recordedInvocations];
                [mUndoManager beginUndoGrouping];
                [[mUndoManager prepareWithInvocationTarget: self] deletedObjectsFromDatabase: [NSArray arrayWithObject: objectID]];
                [[mUndoManager prepareWithInvocationTarget: self] undoWithRedoInvocations: invocations];
                [[mUndoManager prepareWithInvocationTarget: objectID] setLastModificationType: [objectID lastModificationType]];
                [mUndoManager endUndoGrouping];        
                
                //Remember the modification type for ROLLBACK
                [objectID setLastModificationType: kBXInsertModification];
            }
        }
        
        [mSeenEntities addObject: entity];
    }
    BXHandleError (error, localError);
    return rval;
}
//@}

- (BOOL) fireFault: (BXDatabaseObject *) anObject key: (id) aKey error: (NSError **) error
{
    NSError* localError = nil;
    //Always fetch all keys when firing a fault
    BOOL rval = [mDatabaseInterface fireFault: anObject key: nil error: &localError];
    BXHandleError (error, localError);
    return rval;

}

/** \name Deleting database objects */
//@{
/**
 * Delete a database object.
 * Essentially this method deletes a single row from the database.
 * \param       anObject        The object to be deleted
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \return                      A boolean indicating whether the deletion was successful or not
 * \throw       BXException with name \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and a database object couldn't be deleted.
 */
- (BOOL) executeDeleteObject: (BXDatabaseObject *) anObject error: (NSError **) error
{
    return (nil != [self executeDeleteObject: anObject entity: nil predicate: nil error: error]);
}
//@}

/**
 * Rollback the transaction.
 * Guaranteed to succeed
 */
- (void) rollback
{
    if (NO == [mDatabaseInterface autocommits] && [mDatabaseInterface connected])
    {
        //First rollback, then fault and notify the listeners about modifications
        [mDatabaseInterface rollback];

        //FIXME: order by entity either here or in addedObjects and deletedObjects methods
        NSMutableArray* added = [NSMutableArray array];
        NSMutableArray* deleted = [NSMutableArray array];
        TSEnumerate (currentID, e, [mModifiedObjectIDs objectEnumerator])
        {
            switch ([currentID lastModificationType])
            {
                case kBXUpdateModification:
                    [[self registeredObjectWithID: currentID] faultKey: nil];
                    break;
                case kBXInsertModification:
                    [added addObject: currentID];
                    break;
                case kBXDeleteModification:
                    [deleted addObject: currentID];
                    break;
                default:
                    break;
            }
            [currentID setLastModificationType: kBXNoModification];
        }
        [mModifiedObjectIDs removeAllObjects];
        //In case of rollback, the objects deleted during the last transaction 
        //appear as inserted and vice-versa
        //If we are deallocating, don't bother to send the notification.
        if (NO == mDeallocating)
        {
            [self addedObjectsToDatabase: deleted];
            [self deletedObjectsFromDatabase: added];
        }

        [mUndoManager removeAllActions];
    }    
}

/**
 * Commit the current transaction.
 * Undo will be disabled after this.
 * \return      A boolean indicating whether the commit was successful or not
 */
- (BOOL) save: (NSError **) error
{
    BOOL rval = YES;
    if (NO == [mDatabaseInterface autocommits])
    {
        NSError* localError = nil;
        TSEnumerate (currentID, e, [mModifiedObjectIDs objectEnumerator])
            [currentID setLastModificationType: kBXNoModification];
        [mModifiedObjectIDs removeAllObjects];

        [mUndoManager removeAllActions];
        rval = [mDatabaseInterface save: &localError];
        BXHandleError (error, localError);
    }
    return rval;
}

/**
 * Fetch an object with a given ID.
 * The database is queried only if the object is not cached.
 */
- (id) objectWithID: (BXDatabaseObjectID *) anID error: (NSError **) error
{
    id rval = [self registeredObjectWithID: anID];
    if (nil == rval)
    {
        NSError* localError = nil;
        rval = [[self executeFetchForEntity: (BXEntityDescription *) [anID entity] 
                              withPredicate: [anID predicate] returningFaults: NO error: &localError] objectAtIndex: 0];
        [rval awakeFromFetch];
        BXHandleError (error, localError);
    }
    return rval;
}


/**
 * Objects with given IDs.
 * If the objects do not exists yet, they get created.
 * The database is not queried in any case. It is the user's responsibility to
 * provide this method with valid IDs.
 */
- (NSArray *) faultsWithIDs: (NSArray *) anArray
{
    NSMutableArray* rval = nil;
    unsigned int count = [anArray count];
    if (0 < count)
    {
        rval = [NSMutableArray arrayWithCapacity: count];
        TSEnumerate (currentID, e, [anArray objectEnumerator])
        {
            BXDatabaseObject* object = [self registeredObjectWithID: currentID];
            if (nil == object)
            {
                BXEntityDescription* entity = [currentID entity];
                object = [[[[entity databaseObjectClass] alloc] init] autorelease];
                [object registerWithContext: self objectID: currentID];
            }
            [rval addObject: object];
        }
    }
    return rval;
}


- (NSSet *) objectsWithIDs: (NSArray *) anArray error: (NSError **) error
{
    //FIXME: The ids might have different entities
    NSMutableSet* rval = nil;
    if (0 < [anArray count])
    {
        rval = [NSMutableSet setWithCapacity: [anArray count]];
        NSMutableArray* predicates = [NSMutableArray array];
        TSEnumerate (currentID, e, [anArray objectEnumerator])
        {
            id currentObject = [self registeredObjectWithID: currentID];
            if (nil == currentObject)
                [predicates addObject: [currentID predicate]];
            else
                [rval addObject: currentObject];
        }
        
        if (0 < [predicates count])
        {
            NSError* localError = nil;
            NSPredicate* predicate = [NSCompoundPredicate orPredicateWithSubpredicates: predicates];
            [rval addObjectsFromArray: [self executeFetchForEntity: [[anArray objectAtIndex: 0] entity] 
                                                     withPredicate: predicate error: &localError]];
            BXHandleError (error, localError);
        }
    }
    return rval;
}

@end


@implementation BXDatabaseContext (DBInterfaces)

- (void) connectedToDatabase: (NSError **) error
{
	NSAssert1 (NULL != error, @"Expected error to be set (was %p).", error);
	if (nil == *error)
	{
		TSEnumerate (currentEntity, e, [[mLazilyValidatedEntities allObjects] objectEnumerator])
		{
			[mDatabaseInterface validateEntity: currentEntity error: error];
			if (nil != error)
				break;
			[mLazilyValidatedEntities removeObject: currentEntity];
		}
	}
	
	if (nil != *error) [self handleError: *error];
}

- (void) updatedObjectsInDatabase: (NSArray *) objectIDs faultObjects: (BOOL) shouldFault
{
    if (0 < [objectIDs count])
    {
        BXEntityDescription* entity = [[objectIDs objectAtIndex: 0] entity];
        NSArray* objects = [self registeredObjectsWithIDs: objectIDs nullObjects: NO];
        
        if (0 < [objects count])
        {
            //Fault the objects and send the notification
            if (YES == shouldFault)
                [objects makeObjectsPerformSelector: @selector (faultKey:) withObject: nil];
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                objectIDs, kBXObjectIDsKey,
                objects, kBXObjectsKey,
                self, kBXDatabaseContextKey,
                nil];
            
            [[NSNotificationCenter defaultCenter] postNotificationName: kBXUpdateNotification 
                                                                object: entity
                                                              userInfo: userInfo];
        }
        
        //Handle the views.
        //This method will be called recursively, when the changed rows have been determined.
        if (NO == [mDatabaseInterface messagesForViewModifications] && NO == [entity isView])
        {
            NSSet* dependentViews = [entity dependentViews];
            TSEnumerate (currentView, e, [dependentViews objectEnumerator])
            {
                NSMutableArray* viewIDs = [NSMutableArray array];
                TSEnumerate (currentID, e, [objectIDs objectEnumerator])
                {
                    BXDatabaseObjectID* partialID = [currentID partialKeyForView: currentView];
                    if (nil != [self registeredObjectWithID: partialID])
                        [viewIDs addObject: partialID];
                }
                
                [self updatedObjectsInDatabase: viewIDs faultObjects: YES];
            }
        }        
    }
}

- (void) addedObjectsToDatabase: (NSArray *) objectIDs
{
    if (0 < [objectIDs count])
    {
        //If we can find objects with matching partial keys, send update notifications instead
        BXEntityDescription* entity = [[objectIDs objectAtIndex: 0] entity];
        NSMutableArray* insertedIDs = nil;
        NSMutableArray* updatedIDs = nil;
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
                
        //Send the notifications
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            objectIDs, kBXObjectIDsKey,
            self, kBXDatabaseContextKey,
            nil];
        [nc postNotificationName: kBXInsertNotification object: entity userInfo: userInfo];        
        
        if (NO == [mDatabaseInterface messagesForViewModifications] && NO == [entity isView])
        {
            NSSet* dependentViews = [entity dependentViews];
            insertedIDs = [NSMutableArray array];
            updatedIDs = [NSMutableArray array];
            TSEnumerate (currentView, e, [dependentViews objectEnumerator])
            {
                [insertedIDs removeAllObjects];
                [updatedIDs removeAllObjects];
                
                TSEnumerate (currentID, e, [objectIDs objectEnumerator])
                {
                    BXDatabaseObjectID* partialID = [currentID partialKeyForView: currentView];
                    if (nil == [self registeredObjectWithID: partialID])
                        [insertedIDs addObject: partialID];
                    else
                        [updatedIDs addObject: partialID];
                }
                
                NSArray* arrays [2] = {insertedIDs, updatedIDs};
                NSString* notificationNames [2] = {kBXInsertNotification, kBXUpdateNotification};
                id objectArrays [2] = {nil, [self registeredObjectsWithIDs: updatedIDs]};
                for (int i = 0; i < 2; i++)
                {
                    if (0 < [arrays [i] count])
                    {
                        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            [[insertedIDs copy] autorelease], kBXObjectIDsKey,
                            self, kBXDatabaseContextKey,
                            objectArrays [i], kBXObjectsKey, //This needs to be the last item since objectArrays [i] might be nil
                            nil];
                        [nc postNotificationName: notificationNames [i] object: currentView userInfo: userInfo];
                    }
                }
            }
        }        
    }
}

- (void) deletedObjectsFromDatabase: (NSArray *) objectIDs
{
    if (0 < [objectIDs count])
    {
        BXEntityDescription* entity = [[objectIDs objectAtIndex: 0] entity];

        //Send the notification
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            objectIDs, kBXObjectIDsKey,
            [mObjects objectsForKeys: objectIDs notFoundMarker: [NSNull null]], kBXObjectsKey,
            self, kBXDatabaseContextKey,
            nil];
        [[NSNotificationCenter defaultCenter] postNotificationName: kBXDeleteNotification
                                                            object: entity
                                                          userInfo: userInfo];
        
        //This method will be called recursively, when the changed rows have been determined
        if (NO == [mDatabaseInterface messagesForViewModifications] && NO == [entity isView])
        {
            NSSet* dependentViews = [entity dependentViews];
            TSEnumerate (currentView, e, [dependentViews objectEnumerator])
            {
                NSMutableSet* knownIDs = [NSMutableSet set];
                TSEnumerate (currentID, e, [objectIDs objectEnumerator])
                {
                    BXDatabaseObjectID* partialID = [currentID partialKeyForView: currentView];
                    if (nil != [self registeredObjectWithID: partialID])
                        [knownIDs addObject: partialID];
                }
                [self deletedObjectsFromDatabase: [knownIDs allObjects]];
            }
        }
    }
}

- (void) lockedObjectsInDatabase: (NSArray *) objectIDs status: (enum BXObjectStatus) status
{
    unsigned int count = [objectIDs count];
    if (0 < count)
    {
        NSMutableArray* foundObjects = [NSMutableArray arrayWithCapacity: count];
        TSEnumerate (currentID, e, [objectIDs objectEnumerator])
        {
            BXDatabaseObject* object = [self registeredObjectWithID: currentID];
            
            switch (status)
            {
                case kBXObjectDeletedStatus:
                    [object setDeleted];
                    break;
                case kBXObjectLockedStatus:
                    [object setLockedForKey: nil]; //TODO: set the key accordingly
                    break;
                default:
                    break;
            }
            [foundObjects addObject: object];
        }
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            objectIDs, kBXObjectIDsKey,
            self, kBXDatabaseContextKey,
            foundObjects, kBXObjectsKey,
            [NSValue valueWithBytes: &status objCType: @encode (enum BXObjectStatus)], kBXObjectStatusKey,
            nil];
        [[NSNotificationCenter defaultCenter] postNotificationName: kBXLockNotification
                                                            object: [[objectIDs objectAtIndex: 0] entity]
                                                          userInfo: userInfo];
    }
}

- (void) unlockedObjectsInDatabase: (NSArray *) objectIDs
{
    unsigned int count = [objectIDs count];
    if (0 < count)
    {
        NSArray* foundObjects = [self registeredObjectsWithIDs: objectIDs];
        NSMutableArray* iteratedObjects = [NSMutableArray arrayWithCapacity: [foundObjects count]];
        TSEnumerate (currentObject, e, [foundObjects objectEnumerator])
        {
            if ([NSNull null] != currentObject)
            {
#if 0
                [currentObject setDeleted: NO];
                [currentObject setLocked: NO forKey: nil];
#endif
                [currentObject clearStatus];
                [iteratedObjects addObject: currentObject];
            }
        }
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            objectIDs, kBXObjectIDsKey,
            self, kBXDatabaseContextKey, 
            iteratedObjects, kBXObjectsKey,
            nil];
        [[NSNotificationCenter defaultCenter] postNotificationName: kBXUnlockNotification
                                                            object: [[objectIDs objectAtIndex: 0] entity]
                                                          userInfo: userInfo];
    }
}
@end


@implementation BXDatabaseContext (HelperMethods)

- (void) faultKeys: (NSArray *) keys inObjectsWithIDs: (NSArray *) ids
{
    TSEnumerate (currentObject, e, [[self registeredObjectsWithIDs: ids] objectEnumerator])
    {
        if ([NSNull null] != currentObject)
            [currentObject faultKey: nil]; //TODO: set the keys correctly
    }
}

- (NSArray *) objectIDsForEntity: (BXEntityDescription *) anEntity error: (NSError **) error
{
    return [self objectIDsForEntity: anEntity predicate: nil error: error];
}

- (NSArray *) objectIDsForEntity: (BXEntityDescription *) anEntity predicate: (NSPredicate *) predicate error: (NSError **) error
{
    return [[self executeFetchForEntity: anEntity withPredicate: predicate returningFaults: YES error: error] valueForKey: @"objectID"];
}

- (NSArray *) keyPathComponents: (NSString *) keyPath
{
    return [mDatabaseInterface keyPathComponents: keyPath];
}

/**
 * \name Convenience methods for getting entity descriptions.
 */
//@{
/** Entity for a table in a given schema */
- (BXEntityDescription *) entityForTable: (NSString *) tableName inSchema: (NSString *) schemaName error: (NSError **) error
{
    NSError* localError = nil;
    BXEntityDescription* rval =  [BXEntityDescription entityWithURI: mDatabaseURI
                                                              table: tableName
                                                           inSchema: schemaName];
	
	//If the entity was decoded, it might have enough information at this point.
	//Validation takes then place in fetch etc. methods.
	if (NO == [mDatabaseInterface connected] 
		&& nil != [rval fields] && nil != [rval primaryKeyFields])
	{
		if (nil == mLazilyValidatedEntities)
			mLazilyValidatedEntities = [[NSMutableSet alloc] init];
		
		[mLazilyValidatedEntities addObject: rval];
	}
	else
	{
		[self connectIfNeeded: &localError];
		BXHandleError (error, localError);
		[mDatabaseInterface validateEntity: rval error: &localError];
		BXHandleError (error, localError);
		if (nil != localError)
			rval = nil;
	}

    return rval;
}

/** Entity for a table in the default schema */
- (BXEntityDescription *) entityForTable: (NSString *) tableName error: (NSError **) error
{
    return [self entityForTable: tableName
                       inSchema: nil
                          error: error];
}
//@}

/**
 * \name Convenience methods for getting relationship descriptions.
 */
//@{
/** 
 * Relationships between given entities. 
 * Only relationships between tables are returned.
 */
- (NSDictionary *) relationshipsByNameWithEntity: (BXEntityDescription *) anEntity
                                          entity: (BXEntityDescription *) anotherEntity
                                           error: (NSError **) error
{
    return [self relationshipsByNameWithEntity: anEntity
                                        entity: anotherEntity
                                         types: kBXRelationshipUndefined
                                         error: error];
}

/** 
 * Relationships of a specific type between given entities. 
 * Only relationships between tables are returned.
 */
- (NSDictionary *) relationshipsByNameWithEntity: (BXEntityDescription *) anEntity
                                          entity: (BXEntityDescription *) anotherEntity
                                           types: (enum BXRelationshipType) bitmap
                                           error: (NSError **) error
{
    log4Debug (@"RelationshipsByNameWithEntity:entity:types");
    
    //Normalize
    if (nil == anEntity)
    {
        if (nil == anotherEntity)
            return nil;
        else
        {
            anEntity = anotherEntity;
            anotherEntity = nil;
        }
    }
    
    NSError* localError = nil;
    [self connectIfNeeded: &localError];
    BXHandleError (NULL, localError);
    id relationships = [mDatabaseInterface relationshipsByNameWithEntity: anEntity
                                                                  entity: anotherEntity
                                                                   types: bitmap
                                                                   error: &localError];
    BXHandleError (error, localError);
    TSEnumerate (currentRel, e, [relationships objectEnumerator])
    {
        TSEnumerate (currentEntity, e, [[currentRel entities] objectEnumerator])
            [currentEntity cacheRelationship: currentRel];
    }
    return relationships;
}
//@}

@end


@implementation BXDatabaseContext (NSCoding)

- (void) encodeWithCoder: (NSCoder *) encoder
{
    [encoder encodeObject: mDatabaseURI forKey: @"databaseURI"];
    [encoder encodeBool: mLogsQueries forKey: @"logsQueries"];
    [encoder encodeBool: mAutocommits forKey: @"autocommits"];
}

- (id) initWithCoder: (NSCoder *) decoder
{
	if (([self init]))
    {
        [self setDatabaseURI: [decoder decodeObjectForKey: @"databaseURI"]];
        [self setLogsQueries: [decoder decodeBoolForKey: @"logsQueries"]];
        [self setAutocommits: [decoder decodeBoolForKey: @"autocommits"]];
    }
    return self;
}

@end


@implementation BXDatabaseContext (IBActions)
/**
 * \name IBActions
 * Methods for replacing some functionality provided by NSDocument.
 */
//@{
/** 
 * Commit the changes.
 * \param sender Ignored.
 * \throw A BXException named \c kBXFailedToExecuteQueryException if commit fails
 */
- (IBAction) saveDocument: (id) sender
{
    NSError* error = nil;
    [self save: &error];
    if (nil != error)
    {
        [[error BXExceptionWithName: kBXFailedToExecuteQueryException] raise];
    }
}

/**
 * Rollback the changes.
 * \param sender Ignored
 */
- (IBAction) revertDocumentToSaved: (id) sender
{
    [self rollback];
}
//@}

@end


@implementation BXDatabaseContext (PrivateMethods)

/** 
 * \internal
 * Delete multiple objects at the same time. 
 * \note Redoing this re-executes the query with the given predicate and thus
 *       might cause other objects to be deleted than those which were in the original invocation.
 */
- (BOOL) executeDeleteFromEntity: (BXEntityDescription *) anEntity withPredicate: (NSPredicate *) predicate 
                           error: (NSError **) error
{
    return (nil != [self executeDeleteObject: nil entity: anEntity predicate: predicate error: error]);
}

/** 
 * \internal
 * \name Updating existing database objects.
 * These methods should be rarely needed. BXDatabaseObject's -setValue:forKey: should be used instead.
 */
//@{
/** Update a single field in an object. */
- (BOOL) executeUpdateObject: (BXDatabaseObject *) anObject key: (id) aKey value: (id) aValue error: (NSError **) error
{
    return [self executeUpdateObject: anObject 
                      withDictionary: [NSDictionary dictionaryWithObject: aValue forKey: aKey] 
                               error: error];
}

/** Update multiple fields in an object at the same time. */
- (BOOL) executeUpdateObject: (BXDatabaseObject *) anObject withDictionary: (NSDictionary *) aDict error: (NSError **) error
{
    return (nil != [self executeUpdateObject: anObject entity: nil predicate: nil 
                              withDictionary: aDict error: error]);    
}
//@}


/**
 * \internal
 * \param aKey Currently ignored, since PostgreSQL only supports row-level locks.
 */
- (void) lockObject: (BXDatabaseObject *) object key: (id) key status: (enum BXObjectStatus) status
             sender: (id <BXObjectAsynchronousLocking>) sender
{
    [mDatabaseInterface lockObject: object key: key lockType: status sender: sender];    
}

/**
 * \internal
 * \param aKey Currently ignored, since PostgreSQL only supports row-level locks.
 */
- (void) unlockObject: (BXDatabaseObject *) anObject key: (id) aKey
{
    [mDatabaseInterface unlockObject: anObject key: aKey];
}

/**
 * \internal
 * Fetch objects from the database.
 * \param       returnedClass   The class an instance of which gets returned. The class should be a
 *                              subclass of BXContainerProxy.
 */
- (id) executeFetchForEntity: (BXEntityDescription *) entity 
               withPredicate: (NSPredicate *) predicate 
             returningFaults: (BOOL) returnFaults 
             excludingFields: (NSArray *) excludedFields 
               returnedClass: (Class) returnedClass 
                       error: (NSError **) error
{
    NSError* localError = nil;
    id rval = nil;
    [self connectIfNeeded: &localError];
    if (nil == localError)
    {
        //To prevent any problems when objects do not know all their fields, always return faults 
        //when retrieving only a subset of the available fields
        rval = [mDatabaseInterface executeFetchForEntity: entity withPredicate: predicate 
                                         returningFaults: returnFaults excludingFields: excludedFields 
                                                   class: [entity databaseObjectClass] 
                                                   error: &localError];
        
        if (nil == localError)
        {
            [rval makeObjectsPerformSelector: @selector (awakeFromFetch)];
            [mSeenEntities addObject: entity];
            
            if (Nil != returnedClass)
            {
                rval = [[[returnedClass alloc] BXInitWithArray: rval] autorelease];
                [rval setDatabaseContext: self];
                [rval setEntity: entity];
            }
        }
    }
    BXHandleError (error, localError);
    return rval;    
}

/** 
 * \internal
 * Update multiple objects at the same time. 
 * \note Redoing this re-executes the query with the given predicate and thus
 *       might cause modifications in other objects than in the original invocation.
 */
- (NSArray *) executeUpdateEntity: (BXEntityDescription *) anEntity withDictionary: (NSDictionary *) aDict 
                        predicate: (NSPredicate *) predicate error: (NSError **) error
{
    return [self executeUpdateObject: nil entity: anEntity predicate: predicate withDictionary: aDict error: error];
}

//FIXME: do the following methods set modification types correctly in undo & redo, or do they get set in callbacks?
/** 
 * \internal
 * Update multiple objects at the same time. 
 * \note Redoing this re-executes the query with the given predicate and thus
 *       might cause modifications in other objects than in the original invocation.
 */
- (NSArray *) executeUpdateObject: (BXDatabaseObject *) anObject
                           entity: (BXEntityDescription *) anEntity 
                        predicate: (NSPredicate *) predicate 
                   withDictionary: (NSDictionary *) aDict 
                            error: (NSError **) error
{
    NSAssert ((anObject || anEntity) && aDict, @"Expected to be called with parameters.");
    NSError* localError = nil;
    NSArray* objectIDs = [mDatabaseInterface executeUpdateWithDictionary: aDict objectID: [anObject objectID]
                                                                  entity: anEntity predicate: predicate error: error];        
    if (nil == localError)
    {
        //If autocommit is on, the update notification will be received immediately.
        //It won't be handled, though, since it originates from the same connection.
        //Therefore, we need to notify about the change.
        [self updatedObjectsInDatabase: objectIDs faultObjects: NO];

        if (NO == [mDatabaseInterface autocommits])
        {
            [mModifiedObjectIDs addObjectsFromArray: objectIDs];
            
            //For redo
            TSInvocationRecorder* recorder = [TSInvocationRecorder recorder];
            [[recorder recordWithPersistentTarget: self] executeUpdateObject: anObject entity: anEntity 
                                                                   predicate: predicate withDictionary: aDict error: NULL];
            [[recorder recordWithPersistentTarget: self] faultKeys: [aDict allKeys] inObjectsWithIDs: objectIDs];
            
            //Undo manager does things in reverse order
            [mUndoManager beginUndoGrouping];
            //Fault the keys since it probably wouldn't make sense to do it in -undoWithRedoInvocations:
            [[mUndoManager prepareWithInvocationTarget: self] updatedObjectsInDatabase: objectIDs faultObjects: YES];
            [[mUndoManager prepareWithInvocationTarget: self] undoWithRedoInvocations: [recorder recordedInvocations]];
            TSEnumerate (currentID, e, [objectIDs objectEnumerator])
            {
                enum BXModificationType modificationType = [currentID lastModificationType];
                
                [[mUndoManager prepareWithInvocationTarget: currentID] setLastModificationType: modificationType];            
                
                //Remember the modification type for ROLLBACK
                if (! (kBXDeleteModification == modificationType || kBXInsertModification == modificationType))
                    [currentID setLastModificationType: kBXUpdateModification];
            }
            [mUndoManager endUndoGrouping];
        }
    }
    BXHandleError (error, localError);
    return objectIDs;
}

/**
 * \internal
 */
- (NSArray *) executeDeleteObject: (BXDatabaseObject *) anObject 
                           entity: (BXEntityDescription *) entity
                        predicate: (NSPredicate *) predicate
                            error: (NSError **) error
{
    NSError* localError = nil;
    NSArray* objectIDs = [mDatabaseInterface executeDeleteObjectWithID: [anObject objectID] entity: entity 
                                                             predicate: predicate error: &localError];
        
    if (nil == localError)
    {
        //See the private updating method
        [self deletedObjectsFromDatabase: objectIDs];

        if (NO == [mDatabaseInterface autocommits])
        {
            [mModifiedObjectIDs addObjectsFromArray: objectIDs];
            
            //For redo
            TSInvocationRecorder* recorder = [TSInvocationRecorder recorder];
            [[recorder recordWithPersistentTarget: self] executeDeleteObject: anObject entity: entity 
                                                                   predicate: predicate error: NULL];
            [[recorder recordWithPersistentTarget: self] deletedObjectsFromDatabase: objectIDs];
            
            //Undo manager does things in reverse order
            [mUndoManager beginUndoGrouping];
            [[mUndoManager prepareWithInvocationTarget: self] addedObjectsToDatabase: objectIDs];
            [[mUndoManager prepareWithInvocationTarget: self] undoWithRedoInvocations: [recorder recordedInvocations]];
            TSEnumerate (currentID, e, [objectIDs objectEnumerator])
            {
                [[mUndoManager prepareWithInvocationTarget: currentID] setLastModificationType: [currentID lastModificationType]];
                //Remember the modification type for ROLLBACK
                [currentID setLastModificationType: kBXDeleteModification];
            }
            [mUndoManager endUndoGrouping];
        }
    }
    BXHandleError (error, localError);
    return objectIDs;
}

- (BOOL) checkDatabaseURI: (NSError **) error
{
	BOOL rval = YES;
	NSAssert (nil != error, @"Expected error not to be nil.");
	if (nil == mDatabaseURI)
	{
		rval = NO;
		NSString* reason = BXLocalizedString (@"noConnectionURI", @"No connection URI given.", @"Error description");
		NSString* title = BXLocalizedString (@"databaseError", @"Database error", @"Title for a sheet");
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			title, NSLocalizedDescriptionKey,
			reason, NSLocalizedFailureReasonErrorKey, 
			reason, NSLocalizedRecoverySuggestionErrorKey, 
			self, kBXDatabaseContextKey,
			nil];
		*error = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorNoDatabaseURI userInfo: userInfo];
	}
	return rval;
}

- (id <BXInterface>) databaseInterface
{
	if (nil == mDatabaseInterface)
	{
		[self willChangeValueForKey: @"autocommits"];
		mDatabaseInterface = [[[[self class] interfaceClassForScheme: [mDatabaseURI scheme]] alloc] 
            initWithContext: self databaseURI: mDatabaseURI];
		[mDatabaseInterface setAutocommits: mAutocommits];
		[self didChangeValueForKey: @"autocommits"];
		[mDatabaseInterface setLogsQueries: mLogsQueries];
	}
	return mDatabaseInterface;
}

- (void) lazyInit
{
	if (nil == mUndoManager)
		mUndoManager = [[NSUndoManager alloc] init];
	
	if (nil == mSeenEntities)
		mSeenEntities = [[NSMutableSet alloc] init];
	
	if (nil == mObjects)
		mObjects = [[TSNonRetainedObjectDictionary alloc] init];
	
	if (nil == mModifiedObjectIDs)
		mModifiedObjectIDs = [[NSMutableSet alloc] init];        
}

- (BOOL) handleInvalidTrust: (NSValue *) value
{
	BOOL rval = NO;
	struct trustResult trustResult;
	[value getValue: &trustResult];
	SecTrustRef trust = trustResult.trust;
	SecTrustResultType result = trustResult.result;
	
	enum BXCertificatePolicy policy = [mPolicyDelegate BXDatabaseContext: self handleInvalidTrust: trust result: result];
	switch (policy)
	{			
		case kBXCertificatePolicyAllow:
			rval = YES;
			break;
			
		case kBXCertificatePolicyDisplayTrustPanel:
			//This is in BaseTenAppKit framework.
			rval = [self displayPanelForTrust: trust];
			break;

		case kBXCertificatePolicyDeny:
		case kBXCertificatePolicyUndefined:
		default:
			break;
	}
	
	CFRelease (trust);
	return rval;
}

@end
