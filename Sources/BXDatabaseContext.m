//
// BXDatabaseContext.m
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

#import <AppKit/AppKit.h>
#import <stdlib.h>
#import <string.h>
#import <pthread.h>

#import "MKCCollections.h"
#import "PGTS.h"
#import "PGTSFunctions.h"

#import "BXDatabaseAdditions.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXConstants.h"
#import "BXInterface.h"
#import "BXPGInterface.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXConstants.h"
#import "BXException.h"
#import "BXContainerProxy.h"
#import "BXArrayProxy.h"
#import "BXDatabaseContextAdditions.h"
#import "BXConnectionSetupManagerProtocol.h"
#import "BXConstantsPrivate.h"
#import "BXInvocationRecorder.h"
#import "BXErrorHandlerDelegate.h"
#import "BXLogger.h"
            

static NSMutableDictionary* gInterfaceClassSchemes = nil;
static BOOL gHaveAppKitFramework = NO;

#define BXHandleError( ERROR, LOCAL_ERROR ) BXHandleError2( self, errorHandlerDelegate, ERROR, LOCAL_ERROR )

static void
BXHandleError2 (id ctx, id errorHandler, NSError **error, NSError *localError)
{
    if (nil != localError)
    {
        BOOL haveError = (NULL != error);
        [errorHandler BXDatabaseContext: ctx hadError: localError willBePassedOn: haveError];
        if (haveError)
            *error = localError;
    }
}

static NSMutableDictionary*
BXObjectIDsByEntity (NSArray *ids)
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    TSEnumerate (objectID, e, [ids objectEnumerator])
    {
        BXEntityDescription* entity = [(BXDatabaseObjectID *) objectID entity];
        NSMutableArray* array = [dict objectForKey: entity];
        if (nil == array)
        {
            array = [NSMutableArray array];
            [dict setObject: array forKey: entity];
        }
        [array addObject: objectID];
    }
    return dict;
}

static void
BXAddObjectIDsForInheritance2 (NSMutableDictionary *idsByEntity, BXEntityDescription* entity)
{
    id subEntities = [entity subEntities];
    TSEnumerate (currentEntity, e, [subEntities objectEnumerator])
    {
        NSMutableArray* subIds = [idsByEntity objectForKey: currentEntity];
        if (nil == subIds)
        {
            subIds = [NSMutableArray array];
            [idsByEntity setObject: subIds forKey: currentEntity];
        }
        
        //Create the corresponding ids.
        TSEnumerate (objectID, e, [[idsByEntity objectForKey: entity] objectEnumerator])
        {
			NSDictionary* pkeyFields = nil;
			BOOL parsed = [BXDatabaseObjectID parseURI: [objectID URIRepresentation]
												entity: NULL
												schema: NULL
									  primaryKeyFields: &pkeyFields];
			//FIXME: C function logging.
			BXAssertVoidReturn (parsed, @"Expected object URI to be parseable.");
			if (! parsed) break;
			
            BXDatabaseObjectID* newID = [BXDatabaseObjectID IDWithEntity: currentEntity primaryKeyFields: pkeyFields];
            [subIds addObject: newID];
            [newID release];
        }
        BXAddObjectIDsForInheritance2 (idsByEntity, currentEntity);
    }    
}

static void
BXAddObjectIDsForInheritance (NSMutableDictionary *idsByEntity)
{
    TSEnumerate (entity, e, [[idsByEntity allKeys] objectEnumerator])
        BXAddObjectIDsForInheritance2 (idsByEntity, entity);
}

static void
bx_query_during_reconnect ()
{
	NSLog (@"Tried to send a query during reconnection attempt. Break on bx_query_during_reconnect to inspect.");
}


/** 
 * The database context. 
 * A database context connects to a given database, sends queries and commands to it and
 * creates objects from rows in its tables. In order to function properly, it needs an URI formatted 
 * like pgsql://username:password\@hostname/database_name/.
 *
 * Various methods of this class take an NSError parameter. If the parameter isn't set, the context
 * will handle errors by throwing an exception. See #BXDatabaseContext:hadError:willBePassedOn:.
 *
 * \note This class is not thread-safe, i.e. 
 *		 if methods of a BXDatabaseContext instance will be called from 
 *		 different threads the result is undefined and deadlocks are possible.
 * \ingroup BaseTen
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
    BOOL retval = NO;
    if ([aClass conformsToProtocol: @protocol (BXInterface)])
    {
        retval = YES;
        [gInterfaceClassSchemes setValue: aClass forKey: scheme];
    }
    return retval;
}

+ (Class) interfaceClassForScheme: (NSString *) scheme
{
    return [gInterfaceClassSchemes valueForKey: scheme];
}

/** \name Creating a database context */
//@{
/**
 * A convenience method.
 * \param   uri     URI of the target database
 * \return          The database context
 * \throw   NSException named \c kBXUnsupportedDatabaseException in case the given URI cannot be handled.
 */
+ (id) contextWithDatabaseURI: (NSURL *) uri
{
    return [[[self alloc] initWithDatabaseURI: uri] autorelease];
}

/**
 * An initializer.
 * The database URI has to be set afterwards.
 * \return          The database context
 */
- (id) init
{
    return [self initWithDatabaseURI: nil];
}

/**
 * The designated initializer.
 * \param   uri     URI of the target database
 * \return          The database context
 * \throw           NSException named \c kBXUnsupportedDatabaseException in case the given URI cannot be handled.
 */
- (id) initWithDatabaseURI: (NSURL *) uri
{
    if ((self = [super init]))
    {
        [self setDatabaseURI: uri];
        
        mDeallocating = NO;
        mRetainRegisteredObjects = NO;
		mCanConnect = YES;
		mConnectsOnAwake = NO;
		errorHandlerDelegate = self;
		mSendsLockQueries = YES;
		
		mEntities = [[NSMutableSet alloc] init];
		mRelationships = [[NSMutableSet alloc] init];
    }
    return self;
}
//@}

- (void) dealloc
{
    mDeallocating = YES;
    //[self rollback]; //FIXME: I don't think this is really needed.
    if (mRetainRegisteredObjects)
        [mObjects makeObjectsPerformSelector:@selector (release) withObject:nil];
    [mObjects makeObjectsPerformSelector: @selector (BXDatabaseContextWillDealloc) withObject: nil];
    
    [mDatabaseInterface release];
    [mDatabaseURI release];
    [mObjects release];
    [(id) mModifiedObjectIDs release];
    [mUndoManager release];
	[mLazilyValidatedEntities release];
	[mUndoGroupingLevels release];
	[mConnectionSetupManager release];
    [mNotificationCenter release];
    [mEntities release];
    [mRelationships release];
    
    if (NULL != mKeychainPasswordItem)
        CFRelease (mKeychainPasswordItem);
    
    BXLogDebug (@"Deallocating BXDatabaseContext");
    [super dealloc];
}

- (void) finalize
{
	[self rollback];
	[self disconnect];
	[super finalize];
}

/** \name Handling registered objects */
//@{
/**
 * Whether the receiver retains registered objects.
 */
- (BOOL) retainsRegisteredObjects
{
    return mRetainRegisteredObjects;
}

/**
 * Set whether the receiver should retain all registered objects.
 */
- (void) setRetainsRegisteredObjects: (BOOL) flag
{
    if (mRetainRegisteredObjects != flag) {
        mRetainRegisteredObjects = flag;
        
        if (mRetainRegisteredObjects)
            [mObjects makeObjectsPerformSelector:@selector (retain) withObject:nil];
        else
            [mObjects makeObjectsPerformSelector:@selector (release) withObject:nil];
    }
}
//@}

/** \name Connecting and disconnecting */
//@{
/**
 * Set the database URI.
 * \param   uri     The database URI
 * \throw   NSException named \c kBXUnsupportedDatabaseException in case the given URI cannot be handled.
 */
- (void) setDatabaseURI: (NSURL *) uri
{
	[self setDatabaseURIInternal: uri];
	[self setKeychainPasswordItem: NULL];
}

/**
 * The database URI.
 */
- (NSURL *) databaseURI
{
    return mDatabaseURI;
}

/**
 * Whether connection is attempted on -awakeFromNib.
 */
- (BOOL) connectsOnAwake
{
	return mConnectsOnAwake;
}

/**
 * Set whether connection should be attempted on -awakeFromNib.
 */
- (void) setConnectsOnAwake: (BOOL) aBool
{
	mConnectsOnAwake = aBool;
}

/**
 * Establishing a connection.
 * Returns a boolean indicating whether connecting can be attempted using -connect:.
 * Presently this method returns YES when connection attempt hasn't already been started and after
 * the attempt has failed.
 */
- (BOOL) canConnect
{
	return mCanConnect;
}

/**
 * Connection status.
 */
- (BOOL) isConnected
{
	return [[self databaseInterface] connected];
}

/**
 * Connect to the database.
 * This method returns after the connection has been made.
 */
- (void) connectIfNeeded: (NSError **) error
{
    NSError* localError = nil;
	mDidDisconnect = NO;
    if ([self checkDatabaseURI: &localError])
    {
        if (NO == [self isConnected])
        {
			[self setCanConnect: NO];
			[self lazyInit];
			[[self databaseInterface] connectSync: &localError];
			
			if (nil == localError)
				[self connectedToDatabase: (nil == localError) async: NO error: &localError];
			
			if (nil != localError)
			{
				[mDatabaseInterface release];
				mDatabaseInterface = nil;
			}
        }
    }
    BXHandleError (error, localError);
}

/**
 * Connect to the database.
 * Hand over the connection setup to \c mConnectionSetupManager. In BaseTenAppKit 
 * applications, a BXNetServiceConnector will be created automatically if 
 * one doesn't exist.
 */
- (IBAction) connect: (id) sender
{
	if (NO == [[self databaseInterface] connected])
	{
		if (nil == mConnectionSetupManager && 0 != pthread_main_np () &&
            [self respondsToSelector: @selector (copyDefaultConnectionSetupManager)])
		{
			mConnectionSetupManager = [self copyDefaultConnectionSetupManager];
			[mConnectionSetupManager setDatabaseContext: self];
			[mConnectionSetupManager setModalWindow: modalWindow];
		}
		if (nil != mConnectionSetupManager)
		{
			[mConnectionSetupManager connect: sender];
			[self setCanConnect: NO];
		}
	}
}

/**
 * Connect to the database.
 * This method returns immediately.
 * After the attempt, either a \c kBXConnectionSuccessfulNotification or a 
 * \c kBXConnectionFailedNotification will be posted to the context's
 * notification center.
 */
- (void) connect
{
	NSError* localError = nil;
	mDidDisconnect = NO;
	if ([self checkDatabaseURI: &localError])
	{
		if (NO == [self isConnected])
		{
			[self lazyInit];
			[mDatabaseInterface connectAsync];
		}
	}
	
	if (nil == localError)
		[self setCanConnect: NO];
	else
	{
		[mDatabaseInterface release];
		mDatabaseInterface = nil;
		
        NSNotification* notification = [NSNotification notificationWithName: kBXConnectionFailedNotification
                                                                     object: self
                                                                   userInfo: [NSDictionary dictionaryWithObject: localError forKey: kBXErrorKey]];
        [[self notificationCenter] postNotification: notification];
	}	
}

/**
 * Disconnect from the database.
 */
- (void) disconnect
{
	mDidDisconnect = YES;
	[mDatabaseInterface disconnect];
	[mDatabaseInterface release];
	mDatabaseInterface = nil;
}
//@}

/** \name Transactions and undo */
//@{
/**
 * Set the query execution method.
 * In manual commit mode, savepoints are inserted after each query
 * Changes don't get propagated immediately to other clients.
 * Instead, other users get information about locked rows.
 * If the context gets deallocated during a transaction, a ROLLBACK
 * is sent to the database.
 * \note If autocommit is enabled, sending lock queries will be turned off. It may be re-enabled afterwards, though.
 * \param   aBool   Whether or not to use autocommit.
 */
- (void) setAutocommits: (BOOL) aBool
{
	if ([mDatabaseInterface connected])
		[NSException raise: NSInvalidArgumentException format: @"Commit mode cannot be set after connecting."];
    mAutocommits = aBool;
	if (mAutocommits)
		[self setSendsLockQueries: NO];
}

/**
 * Query execution method
 * \return          A BOOL indicating whether or not autocommit is in use.
 */
- (BOOL) autocommits
{
    return mAutocommits;
}

/**
 * Set whether the context should try to lock rows before editing.
 * BaseTen's controller subclasses notify the context in NSEditorRegistration's methods.
 * This method controls whether the context pays attention to those messages.
 * The context may still receive lock notifications from other contexts.
 */
- (void) setSendsLockQueries: (BOOL) aBool
{
	if ([mDatabaseInterface connected])
		[NSException raise: NSInvalidArgumentException format: @"Lock mode cannot be set after connecting."];
	mSendsLockQueries = aBool;
}

/**
 * Whether the context tries to lock rows before editing.
 */
- (BOOL) sendsLockQueries
{
	return mSendsLockQueries;
}

/**
 * The undo manager used by this context.
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
 * \return                  Whether or not changing the undo manager was successful.
 */
- (BOOL) setUndoManager: (NSUndoManager *) aManager
{
    BOOL rval = NO;
    if (aManager == mUndoManager)
        rval = YES;
    else if (0 == [mUndoManager groupingLevel])
    {
        rval = YES;
		NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
		
		[nc removeObserver: self name: NSUndoManagerWillCloseUndoGroupNotification object: mUndoManager];
        [mUndoManager release];
        mUndoManager = [aManager retain];
		[mUndoGroupingLevels removeAllIndexes];
		[nc addObserver: self selector: @selector (undoGroupWillClose:)
				   name: NSUndoManagerWillCloseUndoGroupNotification object: mUndoManager];
    }
    return rval;
}

/**
 * Rollback the transaction ina manual commit mode.
 * Guaranteed to succeed.
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
        TSEnumerate (currentID, e, [(id) mModifiedObjectIDs keyEnumerator])
        {
			BXDatabaseObject* registeredObject = [self registeredObjectWithID: currentID];
            switch ([(id) mModifiedObjectIDs BXModificationTypeForKey: currentID])
            {
                case kBXUpdateModification:
                    [registeredObject removeFromCache: nil postingKVONotifications: YES];
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
			
			if (kBXObjectDeletePending == [registeredObject deletionStatus])
			{
				if (![registeredObject isInserted])
					[registeredObject setDeleted: kBXObjectExists];
				else
				{
					[registeredObject setDeleted: kBXObjectDeleted];
					[registeredObject setCreatedInCurrentTransaction: NO];
				}
			}
			
			[registeredObject clearStatus];
			[registeredObject setDeleted: kBXObjectExists];
        }
        [(id) mModifiedObjectIDs removeAllObjects];
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
 * Commit the current transaction in manual commit mode.
 * Undo will be disabled after this.
 * \return      A boolean indicating whether the commit was successful or not.
 */
- (BOOL) save: (NSError **) error
{
    BOOL retval = YES;
    if ([self checkErrorHandling] && NO == [mDatabaseInterface autocommits])
    {
        NSError* localError = nil;
        TSEnumerate (currentID, e, [(id) mModifiedObjectIDs keyEnumerator])
		{
			BXDatabaseObject* currentObject = [self registeredObjectWithID: currentID];
			[currentObject setCreatedInCurrentTransaction: NO];
			if ([currentObject isDeleted])
				[currentObject setDeleted: kBXObjectDeleted];
		}
        [(id) mModifiedObjectIDs removeAllObjects];
		
        [mUndoManager removeAllActions];
        retval = [mDatabaseInterface save: &localError];
        BXHandleError (error, localError);
    }
    return retval;
}

/** 
 * Commit the changes.
 * \param sender Ignored.
 * \throw A BXException named \c kBXFailedToExecuteQueryException if commit fails.
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
 * \param sender Ignored.
 */
- (IBAction) revertDocumentToSaved: (id) sender
{
    [self rollback];
}
//@}

/** 
 * \name Getting database objects without performing a fetch 
 */
//@{
/**
 * Objects with given IDs.
 * If the objects do not exist yet, they get created.
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
                BXEntityDescription* entity = [(BXDatabaseObjectID *) currentID entity];
                object = [[[[entity databaseObjectClass] alloc] init] autorelease];
                [object registerWithContext: self objectID: currentID];
            }
            [rval addObject: object];
        }
    }
    return rval;
}

/**
 * Retrieve a registered database object.
 * Looks up an object from the cache. The database is not queried in any case.
 * \return The cached object or nil.
 */
- (BXDatabaseObject *) registeredObjectWithID: (BXDatabaseObjectID *) objectID
{
    return [mObjects objectForKey: objectID];
}

/**
 * Retrieve registered database objects.
 * Looks up objects from the cache. The database is not queried in any case.
 * \param objectIDs         The object IDs to look for.
 * \return An NSArray of cached objects and NSNulls.
 */
- (NSArray *) registeredObjectsWithIDs: (NSArray *) objectIDs
{
    return [self registeredObjectsWithIDs: objectIDs nullObjects: YES];
}

/**
 * Retrieve registered database objects.
 * Looks up objects from the cache. The database is not queried in any case.
 * \param objectIDs         The object IDs to look for.
 * \param returnNullObjects Whether the returned array should be filled with NSNulls
 *                          if corresponding objects were not found.
 * \return An NSArray of cached objects and possibly NSNulls.
 */
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
//@}


/** \name Delegates */
//@{
/** 
 * The policy delegate. 
 * \see NSObject(BXPolicyDelegate)
 */
- (id) policyDelegate
{
	return policyDelegate;
}

/**
 * The error handler delegate.
 * \see NSObject(BXErrorHandlerDelegate)
 */ 
- (id) errorHandlerDelegate
{
	return errorHandlerDelegate;
}

/**
 * Set the policy delegate.
 * The delegate object will not be retained.
 * \see NSObject(BXPolicyDelegate)
 */
- (void) setPolicyDelegate: (id) anObject
{
	policyDelegate = anObject;
}

/**
 * Set the error handler delegate.
 * The delegate object will not be retained.
 * \see NSObject(BXErrorHandlerDelegate)
 */
- (void) setErrorHandlerDelegate: (id) anObject
{
	errorHandlerDelegate = anObject;
}
//@}

/** \name Using the Keychain */
//@{
/**
 * Whether the default keychain is searched for database passwords.
 */
- (BOOL) usesKeychain
{
    return mUsesKeychain;
}

/**
 * Set whether the default keychain should be searched for database passwords.
 */
- (void) setUsesKeychain: (BOOL) usesKeychain
{
	mUsesKeychain = usesKeychain;
}

/**
 * Store login credentials from the database URI to the default keychain.
 */
- (void) storeURICredentials
{
    OSStatus status = noErr;
    const char* serverName = [[mDatabaseURI host] UTF8String];
    const char* username = [[mDatabaseURI user] UTF8String];
    const char* path = [[mDatabaseURI path] UTF8String];    
    NSNumber* portObject = [mDatabaseURI port];
    UInt16 port = (portObject ? [portObject unsignedShortValue] : 5432);
    
    NSString* password = [mDatabaseURI password];
    const char* tempPassword = [password UTF8String];
    char* passwordData = strdup (tempPassword ?: "");
    
	SecKeychainItemRef item = NULL;

	if (NULL == mKeychainPasswordItem)
	{
		status = SecKeychainAddInternetPassword (NULL, //Default keychain
												 strlen (serverName), serverName,
												 0, NULL,
												 strlen (username), username,
												 strlen (path), path,
												 port,
												 0, kSecAuthenticationTypeDefault,
												 strlen (passwordData), passwordData, 
												 &item);
		[self setKeychainPasswordItem: item];
	}
	
	if (errSecDuplicateItem == status || (NULL == item && NULL != mKeychainPasswordItem))
	{
		status = SecKeychainItemModifyAttributesAndData (mKeychainPasswordItem, NULL, strlen (passwordData), passwordData);
	}
	
	if (noErr == status)
	{
		[self setKeychainPasswordItem: NULL];
	}
	
    free (passwordData);
}
//@}

/** \name Faulting database objects */
//@{
/**
 * Refresh or fault an object.
 * This method is provided for Core Data compatibility.
 * \param flag   If NO, all the object's cached values including related objects will be released.
 *               A new fetch won't be performed until any of the object's values is requested.
 *               If YES, this is a no-op.
 * \param object The object to fault.
 * \note         Since changes always get sent to the database immediately, this method's behaviour
 *		         is a bit different than in Core Data. When firing a fault, the database
 *               gets queried in any case.
 * \see          BXDatabaseObject::faultKey:
 */
- (void) refreshObject: (BXDatabaseObject *) object mergeChanges: (BOOL) flag
{
    if (NO == flag)
        [object faultKey: nil];
}
//@}

/** \name Receiving notifications */
//@{
/**
 * The notification center for this context.
 * Context-related notifications, such as connection notifications,
 * are posted to this notification center instead of the default center.
 */
- (NSNotificationCenter *) notificationCenter
{
    if (nil == mNotificationCenter)
        mNotificationCenter = [[NSNotificationCenter alloc] init];
    
    return mNotificationCenter;
}
//@}

/** \name Error handling */
//@{
/** The NSWindow used with various sheets. */
- (NSWindow *) modalWindow
{
	return modalWindow;
}

/**
 * Set the NSWindow used with various sheets.
 * If set to nil, application modal alerts will be used.
 */
- (void) setModalWindow: (NSWindow *) aWindow
{
	if (aWindow != modalWindow)
	{
		[modalWindow release];
		modalWindow = [aWindow retain];
	}
}
//@}
@end


#pragma mark UnnamedCategoryEnd


@implementation BXDatabaseContext (Undoing)
- (void) undoGroupWillClose: (NSNotification *) notification
{
	unsigned int groupingLevel = [mUndoManager groupingLevel];
	unsigned int currentLevel = NSNotFound;
	BOOL shouldEstablishSavepoint = NO;
	while (NSNotFound != (currentLevel = [mUndoGroupingLevels lastIndex]))
	{
		if (currentLevel < groupingLevel)
			break;
		
		shouldEstablishSavepoint = YES;
		[mUndoGroupingLevels removeIndex: currentLevel];
	}
	
	if (shouldEstablishSavepoint)
	{
		NSError* localError = nil;
		[mDatabaseInterface establishSavepoint: &localError];
		if (nil != localError)
			[errorHandlerDelegate BXDatabaseContext: self hadError: localError willBePassedOn: NO];
		[[mUndoManager prepareWithInvocationTarget: self] rollbackToLastSavepoint];
	}
}

/**
 * \internal
 * When modifications are made, the respective undo grouping levels get stored in a stack,
 * mUndoGroupingLevels. When an undo group closes, a savepoint gets created for the group.
 * If there is no active undo group, establish the savepoint immediately.
 */
- (BOOL) prepareSavepointIfNeeded: (NSError **) error
{
	BOOL rval = NO;
	NSError* localError = nil;
	int groupingLevel = [mUndoManager groupingLevel];

	BXAssertLog (NULL != error, @"Expected error to be set.");

	if ([mUndoManager isRedoing])
		--groupingLevel;
	
	if (0 == groupingLevel)
	{
		[mDatabaseInterface establishSavepoint: &localError];
		if (nil == localError)
			rval = YES;
	}
	else
	{
		int lastLevel = [mUndoGroupingLevels lastIndex];
		if (lastLevel != groupingLevel)
		{
			BXAssertValueReturn (NSNotFound == (unsigned) lastLevel || lastLevel < groupingLevel, NO, 
								   @"Undo group level stack is corrupt.");
			[mUndoGroupingLevels addIndex: groupingLevel];
		}
	}
	
	if (NULL != error)
		*error = localError;
	
	return rval;
}

- (void) undoWithRedoInvocations: (NSArray *) invocations
{
    [[mUndoManager prepareWithInvocationTarget: self] redoInvocations: invocations];
}

- (void) redoInvocations: (NSArray *) invocations
{
    [invocations makeObjectsPerformSelector: @selector (invoke)];
}

- (void) rollbackToLastSavepoint
{
	NSError* error = nil;
    [mDatabaseInterface rollbackToLastSavepoint: &error];
	//FIXME: in which case does the query fail? Should we be prepared for that?
	if (nil != error)
		[errorHandlerDelegate BXDatabaseContext: self hadError: error willBePassedOn: NO];
}

#if 0
- (void) reregisterObjects: (NSArray *) objectIDs values: (NSDictionary *) pkeyValues
{
	TSEnumerate (currentID, e, [objectIDs objectEnumerator])
	{
		BXDatabaseObject* currentObject = [self registeredObjectWithID: currentID];
		if (nil != currentObject)
		{
			[currentObject setCachedValuesForKeysWithDictionary: pkeyValues];
			[self unregisterObject: currentObject];
			[currentObject registerWithContext: self entity: nil];
		}
	}
}
#endif

- (void) undoUpdateObjects: (NSArray *) objectIDs 
					oldIDs: (NSArray *) oldIDs 
		  createdSavepoint: (BOOL) createdSavepoint 
			   updatedPkey: (BOOL) updatedPkey 
				   oldPkey: (NSDictionary *) oldPkey
		   redoInvocations: (NSArray *) redoInvocations
{
	[[mUndoManager prepareWithInvocationTarget: self] redoInvocations: redoInvocations];
	
	if (createdSavepoint)
		[self rollbackToLastSavepoint];
	
	if (updatedPkey)
	{
		TSEnumerate (currentID, e, [objectIDs objectEnumerator])
		{
			BXDatabaseObject* currentObject = [self registeredObjectWithID: currentID];
			if (nil != currentObject)
			{
				[currentObject setCachedValuesForKeysWithDictionary: oldPkey];
				[self unregisterObject: currentObject];
				[currentObject registerWithContext: self entity: nil];
			}
		}
	}
	[self updatedObjectsInDatabase: oldIDs faultObjects: YES];
}

@end


@implementation BXDatabaseContext (Queries)

/** 
 * \name Retrieving objects from the database
 * These methods block until the result has been retrieved.
 */
//@{
/**
 * Fetch an object with a given ID.
 * The database is queried only if the object isn't in cache.
 */
- (id) objectWithID: (BXDatabaseObjectID *) anID error: (NSError **) error
{
    id retval = [self registeredObjectWithID: anID];
    if (nil == retval && [self checkErrorHandling])
    {
        NSError* localError = nil;
		NSArray* objects = [self executeFetchForEntity: (BXEntityDescription *) [anID entity] 
										 withPredicate: [anID predicate] returningFaults: NO error: &localError];
        if (nil == localError)
        {
            if (0 < [objects count])
            {
                retval = [objects objectAtIndex: 0];
            }
            else
            {
                localError = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorObjectNotFound userInfo: nil];
            }
        }
        BXHandleError (error, localError);
    }
    return retval;
}

/**
 * Fetch objects with given IDs.
 * The database is queried only if the object aren't in cache.
 */
- (NSSet *) objectsWithIDs: (NSArray *) anArray error: (NSError **) error
{
    NSMutableSet* rval = nil;
    if (0 < [anArray count])
    {
        rval = [NSMutableSet setWithCapacity: [anArray count]];
        NSMutableDictionary* entities = [NSMutableDictionary dictionary];
        TSEnumerate (currentID, e, [anArray objectEnumerator])
        {
            id currentObject = [self registeredObjectWithID: currentID];
            if (nil == currentObject)
			{
				BXEntityDescription* entity = [(BXDatabaseObjectID *) currentID entity];
				NSMutableArray* predicates = [entities objectForKey: entity];
				if (nil == predicates)
				{
					predicates = [NSMutableArray array];
					[entities setObject: predicates forKey: entity];
				}
                [predicates addObject: [currentID predicate]];
			}
            else
			{
                [rval addObject: currentObject];
			}
        }
        
        if (0 < [entities count])
        {
            NSError* localError = nil;
			TSEnumerate (currentEntity, e, [entities keyEnumerator])
			{
				NSPredicate* predicate = [NSCompoundPredicate orPredicateWithSubpredicates: [entities objectForKey: currentEntity]];
				NSArray* fetched = [self executeFetchForEntity: currentEntity withPredicate: predicate error: &localError];
				if (nil != localError)
					break;
				[rval addObjectsFromArray: fetched];
			}
            BXHandleError (error, localError);
        }
    }
    return rval;
}

/**
 * Fetch objects from the database.
 * Essentially calls #executeFetchForEntity:withPredicate:returningFaults:error: with \c returningFaults set to NO.
 *  
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException named \c kBXExceptionUnhandledError if \c error is NULL 
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
 * Essentially calls #executeFetchForEntity:withPredicate:returningFaults:updateAutomatically:error: with \c updateAutomatically set to NO.
 *
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       returnFaults    A boolean indicating whether faults should
 *                              be returned or not.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException named \c kBXExceptionUnhandledError if \c error is NULL 
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
 * with \c updateAutomatically set to NO.
 *
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       excludedFields  An NSArray containing the BXPropertyDescriptors for the columns
 *                              that should be excluded. May be nil.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException named \c kBXExceptionUnhandledError if \c error is NULL 
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
                       excludingFields: excludedFields
				   updateAutomatically: NO error: error];
}

/** 
 * Fetch objects from the database.
 * The result array can be set to be updated automatically. 
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       returnFaults    A boolean indicating whether faults should be returned or not.
 * \param       shouldUpdate    A boolean indicating whether the results 
 *                              should be updated by the context or not.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException named \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and the query failed.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time, or an automatically updating NSArray proxy.
 */
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
                    returningFaults: (BOOL) returnFaults updateAutomatically: (BOOL) shouldUpdate error: (NSError **) error
{
	[NSException raise: NSInvalidArgumentException format: @"Entity %@ can't access its relationships.", self];
    return [self executeFetchForEntity: entity withPredicate: predicate
                       returningFaults: returnFaults excludingFields: nil
                         returnedClass: (shouldUpdate ? [BXArrayProxy class] : Nil) 
                                 error: error];
}

/**
 * Fetch objects from the database.
 * The result array can be set to be updated automatically.
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       excludedFields  An NSArray containing the BXPropertyDescriptors for the columns
 *                              that should be excluded. May be nil.
 * \param       shouldUpdate    A boolean indicating whether the results 
 *                              should be updated by the context or not.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \throw       BXException named \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and the query failed.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time, or an automatically updating NSArray proxy.
 */
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
                    excludingFields: (NSArray *) excludedFields updateAutomatically: (BOOL) shouldUpdate error: (NSError **) error
{
	[entity resetAttributeExclusion];
    return [self executeFetchForEntity: entity withPredicate: predicate
                       returningFaults: NO excludingFields: excludedFields
                         returnedClass: (shouldUpdate ? [BXArrayProxy class] : Nil) 
                                 error: error];
}
//@}


/** \name Creating new database objects */
//@{
/**
 * Create a new database object.
 * Essentially inserts a new row into the database and retrieves it.
 * \param       entity           The target entity.
 * \param       givenFieldValues Initial values for fields. May be nil or left empty if
 *                               values for the primary key can be determined by the database.
 * \param       error            If an error occurs, this pointer is set to an NSError instance.
 *                               May be NULL.
 * \return                       A subclass of BXDatabaseObject or nil, if an error has occured.
 * \throw       BXException named \c kBXExceptionUnhandledError if \c error is NULL 
 *              and a database object couldn't be created.
 */
- (id) createObjectForEntity: (BXEntityDescription *) entity 
             withFieldValues: (NSDictionary *) givenFieldValues 
                       error: (NSError **) error
{
    NSError* localError = nil;
    BXDatabaseObject* retval = nil;
	if ([self checkErrorHandling] && [self checkDatabaseURI: &localError])
	{
		[self connectIfNeeded: &localError];
		if (nil == localError)
		{
			//The interface wants only attribute descriptions as keys
			NSMutableDictionary* fieldValues = [NSMutableDictionary dictionaryWithCapacity: [givenFieldValues count]];
			Class attributeDescriptionClass = [BXAttributeDescription class];
			Class stringClass = [NSString class];
			TSEnumerate (currentKey, e, [givenFieldValues keyEnumerator])
			{
				id value = [givenFieldValues objectForKey: currentKey];
				if ([currentKey isKindOfClass: attributeDescriptionClass])
					[fieldValues setObject: value forKey: currentKey];
				else if ([currentKey isKindOfClass: stringClass])
				{
					//We connected earlier so no need for an assertion.
					BXAttributeDescription* attr = [[entity attributesByName] valueForKey: currentKey];
					[fieldValues setObject: value forKey: attr];
				}
			}
			
			//First make the object
			retval = [mDatabaseInterface createObjectForEntity: entity withFieldValues: fieldValues
													   class: [entity databaseObjectClass]
													   error: &localError];
			
			//Then use the values received from the database with the redo invocation
			if (nil != retval && nil == localError)
			{
                //If registration fails, there should be a suitable object in memory.
                if (NO == [retval registerWithContext: self entity: entity])
                    retval = [self registeredObjectWithID: [retval objectID]];
				BXDatabaseObjectID* objectID = [retval objectID];
				
				if (YES == [mDatabaseInterface autocommits])
				{
					if (! [entity getsChangedByTriggers])
						[self addedObjectsToDatabase: [NSArray arrayWithObject: objectID]];
					[retval awakeFromInsertIfNeeded];
				}
				else
				{
					[retval setCreatedInCurrentTransaction: YES];
					BOOL createdSavepoint = [self prepareSavepointIfNeeded: &localError];
					if (nil == localError)
					{
						if (! [entity getsChangedByTriggers])
							[self addedObjectsToDatabase: [NSArray arrayWithObject: objectID]];
						[retval awakeFromInsertIfNeeded];
						
						//For redo
						BXInvocationRecorder* recorder = [BXInvocationRecorder recorder];
						NSMutableDictionary* values = [NSMutableDictionary dictionary];
						[values addEntriesFromDictionary: [retval cachedObjects]];
						[[recorder recordWithPersistentTarget: self] createObjectForEntity: entity 
																		   withFieldValues: values
																					 error: NULL];
						
						//Undo manager does things in reverse order
						NSArray* invocations = [recorder recordedInvocations];
						if (![mUndoManager groupsByEvent])
    						[mUndoManager beginUndoGrouping];
						[[mUndoManager prepareWithInvocationTarget: self] deletedObjectsFromDatabase: [NSArray arrayWithObject: objectID]];
						if (createdSavepoint)
							[[mUndoManager prepareWithInvocationTarget: self] rollbackToLastSavepoint];
						[[mUndoManager prepareWithInvocationTarget: self] undoWithRedoInvocations: invocations];
						[[mUndoManager prepareWithInvocationTarget: (id) mModifiedObjectIDs] BXSetModificationType: 
                                               [(id) mModifiedObjectIDs BXModificationTypeForKey: objectID] forKey: objectID];
						if (![mUndoManager groupsByEvent])
    						[mUndoManager endUndoGrouping];        
						
						//Remember the modification type for ROLLBACK
                        [(id) mModifiedObjectIDs BXSetModificationType: kBXInsertModification forKey: objectID];
					}
				}
			}
		}		
	}
	BXHandleError (error, localError);
	return retval;
}
//@}

- (BOOL) fireFault: (BXDatabaseObject *) anObject key: (id) aKey error: (NSError **) error
{
    NSError* localError = nil;
	BOOL retval = NO;
	if ([self checkErrorHandling])
	{
	    //Always fetch all keys when firing a fault
		NSArray* keys = [anObject keysIncludedInQuery: aKey];
	    retval = [mDatabaseInterface fireFault: anObject keys: keys error: &localError];
		if (YES == retval)
			[anObject awakeFromFetchIfNeeded];
	    BXHandleError (error, localError);
	}
	else
	{
		retval = YES;
	}
    return retval;
}

/** \name Deleting database objects */
//@{
/**
 * Delete a database object.
 * Essentially this method deletes a single row from the database.
 * \param       anObject        The object to be deleted.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \return                      A boolean indicating whether the deletion was successful or not.
 * \throw       BXException named \c kBXExceptionUnhandledError if \c error is NULL 
 *                              and a database object couldn't be deleted.
 */
- (BOOL) executeDeleteObject: (BXDatabaseObject *) anObject error: (NSError **) error
{
    return (nil != [self executeDeleteObject: anObject entity: nil predicate: nil error: error]);
}
//@}

/** \name Executing arbitrary queries */
//@{
/**
 * Execute a query directly.
 * This method should only be used when fetching objects and modifying 
 * them is cumbersome or doesn't accomplish the task altogether.
 * \return An NSArray of NSDictionaries that correspond to each row.
 */
- (NSArray *) executeQuery: (NSString *) queryString error: (NSError **) error
{
	return [self executeQuery: queryString parameters: nil error: error];
}

/**
 * Execute a query directly.
 * This method should only be used when fetching objects and modifying 
 * them is cumbersome or doesn't accomplish the task altogether.
 * \param parameters An NSArray of objects that are passed as replacements for $1, $2 etc. in the query.
 * \return An NSArray of NSDictionaries that correspond to each row.
 */
- (NSArray *) executeQuery: (NSString *) queryString parameters: (NSArray *) parameters error: (NSError **) error
{
	NSError* localError = nil;
	id retval = nil;
	if ([self checkErrorHandling])
	{
		[self connectIfNeeded: &localError];
    	if (nil == localError)
			retval = [mDatabaseInterface executeQuery: queryString parameters: parameters error: &localError];
		BXHandleError (error, localError);
	}
	return retval;
}

/**
 * Execute a command directly.
 * This method should only be used when fetching objects and modifying 
 * them is cumbersome or doesn't accomplish the task altogether.
 * \return The number of rows affected by the command.
 */
- (unsigned long long) executeCommand: (NSString *) commandString error: (NSError **) error
{
	NSError* localError = nil;
	unsigned long long retval = 0;
	if ([self checkErrorHandling])
	{
		[self connectIfNeeded: &localError];
		if (nil == localError)
			retval = [mDatabaseInterface executeCommand: commandString error: &localError];
		BXHandleError (error, localError);
	}
	return retval;
}
//@}
@end


@implementation BXDatabaseContext (DBInterfaces)

- (NSError *) packQueryError: (NSError *) error
{
	NSString* title = BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet");
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
									 title, NSLocalizedDescriptionKey,
									 self, kBXDatabaseContextKey,
									 nil];
	if (error) 
	{
		[userInfo setObject: error forKey: NSUnderlyingErrorKey];
		if ([error localizedFailureReason])
			[userInfo setObject: [error localizedFailureReason] forKey: NSLocalizedFailureReasonErrorKey];
		if ([error localizedRecoverySuggestion])
			[userInfo setObject: [error localizedRecoverySuggestion] forKey: NSLocalizedRecoverySuggestionErrorKey];
	}
	return [NSError errorWithDomain: kBXErrorDomain code: kBXErrorUnsuccessfulQuery userInfo: userInfo];	
}

- (void) connectionLost: (NSError *) error
{
	[errorHandlerDelegate BXDatabaseContext: self lostConnection: error];
}

- (void) connectedToDatabase: (BOOL) connected async: (BOOL) async error: (NSError **) error;
{
	BXAssertLog (NULL != error || (YES == async && YES == connected), @"Expected error to be set.");
	
	if (NO == connected)
	{
		if (NO == mDisplayingSheet)
		{
			NSString* domain = nil;
			int code = 0;
			if (NULL != error)
			{
				domain = [*error domain];
				code = [*error code];
			}
			BOOL authenticationFailed = NO;
			BOOL certificateVerifyFailed = NO;
			if ([domain isEqualToString: kBXErrorDomain])
			{
				switch (code)
				{
					case kBXErrorAuthenticationFailed:
						authenticationFailed = YES;
						break;
					case kBXErrorSSLError:
						certificateVerifyFailed = YES;
						break;
					default:
						break;
				}
			}
			
			if (!mRetryingConnection && (authenticationFailed || certificateVerifyFailed))
			{
				mRetryingConnection = YES;
				[self connect];
			}
			else
			{
                //If we have a keychain item, mark it invalid.
                if (NULL != mKeychainPasswordItem && authenticationFailed)
                {
                    //FIXME: enable this after debugging
#if 0
                    OSStatus status = noErr;
                    Boolean value = TRUE;
                    SecKeychainAttribute attribute = {.tag = kSecNegativeItemAttr, .length = sizeof (Boolean), .data = &value};
                    SecKeychainAttributeList attributeList = {.count = 1, .attr = &attribute};
                    status = SecKeychainItemModifyAttributesAndData (mKeychainPasswordItem, &attributeList, 0, NULL);
#endif
                }
                
				mRetryingConnection = NO;
				
				//If we have a connection setup manager, it will call a method when it's finished.
				if (nil == mConnectionSetupManager)
					[self setCanConnect: YES];
				
				//Don't set the error if we were supposed to disconnect.
				NSNotification* notification = [NSNotification notificationWithName: kBXConnectionFailedNotification
																			 object: self 
																		   userInfo: (mDidDisconnect ? nil : [NSDictionary dictionaryWithObject: *error forKey: kBXErrorKey])];
				[[self notificationCenter] postNotification: notification];
				
				//Strip password from the URI
                //FIXME: should we remove the username as well?
				NSURL* newURI = [mDatabaseURI BXURIForHost: nil database: nil username: nil password: @""];
				[self setDatabaseURIInternal: newURI];				
			}
		}
	}
	else //YES == connected
	{
		NSError* localError = nil;

		//Strip password from the URI
		NSURL* newURI = [mDatabaseURI BXURIForHost: nil database: nil username: nil password: @""];
		[self setDatabaseURIInternal: newURI];
		
        //This might have changed during connection.
        TSEnumerate (currentEntity, e, [[mLazilyValidatedEntities allObjects] objectEnumerator])
            [currentEntity setDatabaseURI: mDatabaseURI];
        [self iterateValidationQueue: &localError];
		
		mRetryingConnection = NO;
		NSNotification* notification = nil;
		if (nil == localError)
		{
			notification = [NSNotification notificationWithName: kBXConnectionSuccessfulNotification
														 object: self 
													   userInfo: nil];			
		}
		else
		{
			if (NULL != error)
				*error = localError;
			[mDatabaseInterface disconnect];
			notification = [NSNotification notificationWithName: kBXConnectionFailedNotification
														 object: self
													   userInfo: [NSDictionary dictionaryWithObject: localError forKey: kBXErrorKey]];
		}
		[[self notificationCenter] postNotification: notification];
	}
	[self setConnectionSetupManager: nil];
}

- (void) updatedObjectsInDatabase: (NSArray *) objectIDs faultObjects: (BOOL) shouldFault
{
    if (0 < [objectIDs count])
    {
		NSMutableDictionary* idsByEntity = BXObjectIDsByEntity (objectIDs);
		BXAddObjectIDsForInheritance (idsByEntity);
		NSNotificationCenter* nc = [self notificationCenter];

		TSEnumerate (entity, e, [idsByEntity keyEnumerator])
		{
			NSArray* objectIDs = [idsByEntity objectForKey: entity];
			NSArray* objects = [self registeredObjectsWithIDs: objectIDs nullObjects: NO];
			
			if (0 < [objects count])
			{
				//Fault the objects and send the notification
				if (YES == shouldFault)
				{
					TSEnumerate (currentObject, e, [objects objectEnumerator])
						[currentObject removeFromCache: nil postingKVONotifications: YES];
				}
				
				NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  objectIDs, kBXObjectIDsKey,
										  objects, kBXObjectsKey,
										  self, kBXDatabaseContextKey,
										  nil];
				
				id notificationNames [2] = {kBXUpdateEarlyNotification, kBXUpdateNotification};
				for (int i = 0; i < 2; i++)
				{
					[nc postNotificationName: notificationNames [i]
									  object: entity
									userInfo: userInfo];
				}
			}
			
#if 0
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
#endif			
		}
    }
}

- (void) addedObjectsToDatabase: (NSArray *) objectIDs
{
    if (0 < [objectIDs count])
    {
        NSMutableDictionary* idsByEntity = BXObjectIDsByEntity (objectIDs);
        BXAddObjectIDsForInheritance (idsByEntity);
        NSNotificationCenter* nc = [self notificationCenter];
        		
        //Post the notifications
        TSEnumerate (entity, e, [idsByEntity keyEnumerator])
        {
            NSArray* objectIDs = [idsByEntity objectForKey: entity];

            //Send the notifications
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                objectIDs, kBXObjectIDsKey,
                self, kBXDatabaseContextKey,
                nil];
            NSString* notificationNames [2] = {kBXInsertEarlyNotification, kBXInsertNotification};
            for (int i = 0; i < 2; i++)
                [nc postNotificationName: notificationNames [i] object: entity userInfo: userInfo];
            
#if 0
            //If we can find objects with matching partial keys, send update notifications instead
            if (NO == [mDatabaseInterface messagesForViewModifications] && NO == [entity isView])
            {
                NSSet* dependentViews = [entity dependentViews];
                NSMutableArray* insertedIDs = [NSMutableArray array];
                NSMutableArray* updatedIDs = [NSMutableArray array];
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
                    
                    id updatedIds = [self registeredObjectsWithIDs: updatedIDs];
                    NSString* notificationNames [4] = {
                        kBXInsertEarlyNotification, 
                        kBXUpdateEarlyNotification,
                        kBXInsertNotification, 
                        kBXUpdateNotification
                    };
                    NSArray* arrays [4] = {insertedIDs, updatedIDs, insertedIDs, updatedIDs};
                    id objectArrays [4] = {nil, updatedIds, nil, updatedIds};
                    for (int i = 0; i < 4; i++)
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
#endif            
        }
    }
}

- (void) deletedObjectsFromDatabase: (NSArray *) objectIDs
{
	if (0 < [objectIDs count])
    {
        NSMutableDictionary* idsByEntity = BXObjectIDsByEntity (objectIDs);
        BXAddObjectIDsForInheritance (idsByEntity);
        NSNotificationCenter* nc = [self notificationCenter];
		
        //Post the notifications
        TSEnumerate (entity, e, [idsByEntity keyEnumerator])
        {
			TSEnumerate (currentID, e, [objectIDs objectEnumerator])
				[[self registeredObjectWithID: currentID] setDeleted: kBXObjectDeleted];
        
			id objects = [mObjects objectsForKeys: objectIDs notFoundMarker: [NSNull null]];
        
			//Send the notifications
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  objectIDs, kBXObjectIDsKey,
									  objects, kBXObjectsKey,
									  self, kBXDatabaseContextKey,
									  nil];
			const int count = 2;
			NSString* notificationNames [2] = {kBXDeleteEarlyNotification, kBXDeleteNotification};
			for (int i = 0; i < count; i++)
			{
				[nc postNotificationName: notificationNames [i]
								  object: entity
								userInfo: userInfo];
			}
        
#if 0
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
#endif
		}
	}
}
		
- (void) lockedObjectsInDatabase: (NSArray *) objectIDs status: (enum BXObjectLockStatus) status
{
    unsigned int count = [objectIDs count];
    if (0 < count)
    {
        NSMutableArray* foundObjects = [NSMutableArray arrayWithCapacity: count];
        TSEnumerate (currentID, e, [objectIDs objectEnumerator])
        {
            BXDatabaseObject* object = [self registeredObjectWithID: currentID];
            if (nil != object)
			{
				switch (status)
				{
					case kBXObjectDeletedStatus:
						[object lockForDelete];
						break;
					case kBXObjectLockedStatus:
						[object setLockedForKey: nil]; //TODO: set the key accordingly
						break;
					default:
						break;
				}
				[foundObjects addObject: object];
			}
		}
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            objectIDs, kBXObjectIDsKey,
            self, kBXDatabaseContextKey,
            foundObjects, kBXObjectsKey,
            [NSValue valueWithBytes: &status objCType: @encode (enum BXObjectLockStatus)], kBXObjectLockStatusKey,
            nil];
        [[self notificationCenter] postNotificationName: kBXLockNotification
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
                [currentObject clearStatus];
                [iteratedObjects addObject: currentObject];
            }
        }
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            objectIDs, kBXObjectIDsKey,
            self, kBXDatabaseContextKey, 
            iteratedObjects, kBXObjectsKey,
            nil];
        [[self notificationCenter] postNotificationName: kBXUnlockNotification
                                                 object: [[objectIDs objectAtIndex: 0] entity]
                                               userInfo: userInfo];
    }
}

- (BOOL) handleInvalidTrust: (SecTrustRef) trust result: (SecTrustResultType) result
{
	BOOL retval = NO;
	enum BXCertificatePolicy policy = [policyDelegate BXDatabaseContext: self handleInvalidTrust: trust result: result];
	switch (policy)
	{			
		case kBXCertificatePolicyAllow:
		case kBXCertificatePolicyUndefined:
			retval = YES;
			break;
			
		case kBXCertificatePolicyDeny:
		default:
			break;
	}
	return retval;
}

- (void) handleInvalidCopiedTrustAsync: (NSValue *) value
{
	struct BXTrustResult trustResult = {};
	[value getValue: &trustResult];
	SecTrustRef trust = trustResult.trust;
	SecTrustResultType result = trustResult.result;
	
	enum BXCertificatePolicy policy = kBXCertificatePolicyUndefined;
	if ([policyDelegate respondsToSelector: @selector (BXDatabaseContext:handleInvalidTrust:result:)])
		policy = [policyDelegate BXDatabaseContext: self handleInvalidTrust: trust result: result];
	if (gHaveAppKitFramework && kBXCertificatePolicyUndefined == policy)
		policy = kBXCertificatePolicyDisplayTrustPanel;
	
	switch (policy)
	{			
		case kBXCertificatePolicyAllow:
			[self connect];
			break;
			
		case kBXCertificatePolicyDisplayTrustPanel:
			//These are in BaseTenAppKit framework.
			if (nil == mConnectionSetupManager)
				[self displayPanelForTrust: trust];
			else
				[mConnectionSetupManager BXDatabaseContext: self displayPanelForTrust: trust];
			
			break;
			
		case kBXCertificatePolicyDeny:
		case kBXCertificatePolicyUndefined:
		default:
			break;
	}
	
	CFRelease (trust);
}

- (enum BXSSLMode) sslMode
{
	enum BXSSLMode mode = kBXSSLModeDisable;
	if (NO == mRetryingConnection && [policyDelegate respondsToSelector: @selector (BXSSLModeForDatabaseContext:)])
		mode = [policyDelegate BXSSLModeForDatabaseContext: self];
	return (kBXSSLModeUndefined == mode ? kBXSSLModePrefer : mode);
}
@end


@implementation BXDatabaseContext (HelperMethods)
- (NSDictionary *) entitiesBySchemaAndName: (NSError **) error
{
	//FIXME: cache these?
	//FIXME: error handling.
	NSError* localError = nil;
	return [mDatabaseInterface entitiesBySchemaAndName: &localError];
}

- (NSArray *) objectIDsForEntity: (BXEntityDescription *) anEntity error: (NSError **) error
{
    return [self objectIDsForEntity: anEntity predicate: nil error: error];
}

- (NSArray *) objectIDsForEntity: (BXEntityDescription *) anEntity predicate: (NSPredicate *) predicate error: (NSError **) error
{
    return [[self executeFetchForEntity: anEntity withPredicate: predicate returningFaults: YES error: error] valueForKey: @"objectID"];
}

/**
 * \name Getting entity descriptions
 */
//@{
/** Entity for a table in the given schema */
- (BXEntityDescription *) entityForTable: (NSString *) tableName inSchema: (NSString *) schemaName error: (NSError **) error
{
    return [self entityForTable: tableName
                       inSchema: schemaName
            validateImmediately: [self isConnected]
                          error: error];
}

/** Entity for a table in the default schema */
- (BXEntityDescription *) entityForTable: (NSString *) tableName error: (NSError **) error
{
    return [self entityForTable: tableName
                       inSchema: nil
                          error: error];
}
//@}

@end


@implementation BXDatabaseContext (NSCoding)

- (void) encodeWithCoder: (NSCoder *) encoder
{
    [encoder encodeObject: mDatabaseURI forKey: @"databaseURI"];
    [encoder encodeBool: mAutocommits forKey: @"autocommits"];
	[encoder encodeBool: mConnectsOnAwake forKey: @"connectsOnAwake"];
}

- (id) initWithCoder: (NSCoder *) decoder
{
	if (([self init]))
    {
        [self setDatabaseURI: [decoder decodeObjectForKey: @"databaseURI"]];
        [self setAutocommits: [decoder decodeBoolForKey: @"autocommits"]];
		[self setConnectsOnAwake: [decoder decodeBoolForKey: @"connectsOnAwake"]];
    }
    return self;
}

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
 * \param aKey Currently ignored, since PostgreSQL only supports row-level locks.
 */
- (void) lockObject: (BXDatabaseObject *) object key: (id) key status: (enum BXObjectLockStatus) status
             sender: (id <BXObjectAsynchronousLocking>) sender
{
	if (mSendsLockQueries && [self checkErrorHandling]) [mDatabaseInterface lockObject: object key: key lockType: status sender: sender];    
}

/**
 * \internal
 * \param aKey Currently ignored, since PostgreSQL only supports row-level locks.
 */
- (void) unlockObject: (BXDatabaseObject *) anObject key: (id) aKey
{
    if (mSendsLockQueries && [self checkErrorHandling]) [mDatabaseInterface unlockObject: anObject key: aKey];
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
    id retval = nil;
	if ([self checkErrorHandling])
	{
		[self connectIfNeeded: &localError];
		if (nil == localError)
		{
			if (nil != excludedFields)
			{
				excludedFields = [entity attributes: excludedFields];
				[excludedFields setValue: [NSNumber numberWithBool: YES] forKey: @"excluded"];
			}
			retval = [mDatabaseInterface executeFetchForEntity: entity withPredicate: predicate 
											   returningFaults: returnFaults 
														 class: [entity databaseObjectClass] 
														 error: &localError];
			if (nil == localError)
			{
				[retval makeObjectsPerformSelector: @selector (awakeFromFetchIfNeeded)];
				
				if (Nil != returnedClass)
				{
					retval = [[[returnedClass alloc] BXInitWithArray: retval] autorelease];
					[retval setDatabaseContext: self];
					[(BXContainerProxy *) retval setEntity: entity];
					[retval setFilterPredicate: predicate];
				}
				else if (0 == [retval count])
				{
					//If an automatically updating container wasn't desired, we could also return nil.
					retval = nil;
				}
			}
		}
		BXHandleError (error, localError);
	}
	return retval;    
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
	BXAssertValueReturn ((anObject || anEntity) && aDict, nil, @"Expected to be called with parameters.");
    NSError* localError = nil;
	NSArray* objectIDs = nil;
	if ([self checkErrorHandling] && [self checkDatabaseURI: &localError])
	{
        NSArray* primaryKeyFields = [[[anObject objectID] entity] primaryKeyFields];
        if (nil == primaryKeyFields)
            primaryKeyFields = [anEntity primaryKeyFields];
        BOOL updatedPkey = (nil != [primaryKeyFields firstObjectCommonWithArray: [aDict allKeys]]);
        BXAssertValueReturn (!updatedPkey || anObject, nil, 
                               @"Expected anObject to be known in case its pkey should be modified.");

		NSDictionary* oldPkey = nil;
		if (updatedPkey)
			oldPkey = [anObject primaryKeyFieldObjects];

		objectIDs = [mDatabaseInterface executeUpdateWithDictionary: aDict objectID: [anObject objectID]
															 entity: anEntity predicate: predicate error: &localError];
		
		if (nil == localError)
        {
            NSArray* oldIDs = objectIDs;
            if (updatedPkey)
                oldIDs = [NSArray arrayWithObject: [anObject objectID]];
            
            //If autocommit is on, the update notification will be received immediately.
            //It won't be handled, though, since it originates from the same connection.
            //Therefore, we need to notify about the change.
            if (YES == [mDatabaseInterface autocommits])
			{
				if (! [anEntity getsChangedByTriggers])
					[self updatedObjectsInDatabase: oldIDs faultObjects: NO];
				//FIXME: move this to the if block where oldIDs are set.
				if (updatedPkey)
				{
					[self unregisterObject: anObject];
					[anObject registerWithContext: self entity: nil];
				}						
			}
            else
            {
                BOOL createdSavepoint = [self prepareSavepointIfNeeded: &localError];
                if (nil == localError)
                {
                    //This is needed for self-updating collections.
					if (! [anEntity getsChangedByTriggers])
						[self updatedObjectsInDatabase: oldIDs faultObjects: NO];
                    
                    //For redo
                    BXInvocationRecorder* recorder = [BXInvocationRecorder recorder];
                    [[recorder recordWithPersistentTarget: self] executeUpdateObject: anObject entity: anEntity 
                                                                           predicate: predicate withDictionary: aDict error: NULL];
#if 0
                    //Finally fault the object.
                    //FIXME: do we need this either?
                    [[recorder recordWithPersistentTarget: self] faultKeys: [aDict allKeys] inObjectsWithIDs: objectIDs];
#endif
                    
					//For undo
                    //Undo manager does things in reverse order.
					[[mUndoManager prepareWithInvocationTarget: self] undoUpdateObjects: objectIDs
																				 oldIDs: oldIDs
																	   createdSavepoint: createdSavepoint
																			updatedPkey: updatedPkey
																				oldPkey: oldPkey
																		redoInvocations: [recorder recordedInvocations]];                    

                    //Set the modification type. No need for undo since insert and delete override this anyway.
                    TSEnumerate (currentID, e, [objectIDs objectEnumerator])
                    {
                        enum BXModificationType modificationType = [(id) mModifiedObjectIDs BXModificationTypeForKey: currentID];
                        if (! (kBXDeleteModification == modificationType || kBXInsertModification == modificationType))
                            [(id) mModifiedObjectIDs BXSetModificationType: kBXUpdateModification forKey: currentID];
                    }
                    
					//FIXME: move this to the if block where oldIDs are set.
					if (updatedPkey)
					{
						[self unregisterObject: anObject];
						[anObject registerWithContext: self entity: nil];
					}											
                }
            }
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
	NSArray* objectIDs = nil;
	if ([self checkErrorHandling] && [self checkDatabaseURI: &localError])
	{
		objectIDs = [mDatabaseInterface executeDeleteObjectWithID: [anObject objectID] entity: entity 
														predicate: predicate error: &localError];
        
		if (nil == localError)
		{
			//See the private updating method
			
			if (YES == [mDatabaseInterface autocommits])
			{
				if (! [entity getsChangedByTriggers])
					[self deletedObjectsFromDatabase: objectIDs];
			}
			else
			{
				BOOL createdSavepoint = [self prepareSavepointIfNeeded: &localError];
				if (nil == localError)
				{
					TSEnumerate (currentID, e, [objectIDs objectEnumerator])
                        [[self registeredObjectWithID: currentID] setDeleted: kBXObjectDeletePending];
					
					if (! [entity getsChangedByTriggers])
						[self deletedObjectsFromDatabase: objectIDs];

					//For redo
					BXInvocationRecorder* recorder = [BXInvocationRecorder recorder];
					[[recorder recordWithPersistentTarget: self] executeDeleteObject: anObject entity: entity 
																		   predicate: predicate error: NULL];
					
					//Undo manager does things in reverse order.
					if (![mUndoManager groupsByEvent])
    					[mUndoManager beginUndoGrouping];

					[[mUndoManager prepareWithInvocationTarget: self] addedObjectsToDatabase: objectIDs];
                    //Object status.
                    TSEnumerate (currentID, e, [objectIDs objectEnumerator])
					{
						enum BXObjectDeletionStatus status = [[self registeredObjectWithID: currentID] deletionStatus];
						[[mUndoManager prepareWithInvocationTarget: currentID] setStatus: status forObjectRegisteredInContext: self];
					}
                    //Do the actual rollback.
					if (createdSavepoint)
						[[mUndoManager prepareWithInvocationTarget: self] rollbackToLastSavepoint];
					[[mUndoManager prepareWithInvocationTarget: self] undoWithRedoInvocations: [recorder recordedInvocations]];
                    //Remember the modification type for ROLLBACK.
					TSEnumerate (currentID, e, [objectIDs objectEnumerator])
					{
                        [[mUndoManager prepareWithInvocationTarget: (id) mModifiedObjectIDs] BXSetModificationType:
                                              [(id) mModifiedObjectIDs BXModificationTypeForKey: currentID] forKey: currentID];                        
                        [(id) mModifiedObjectIDs BXSetModificationType: kBXDeleteModification forKey: currentID];
					}
					if (![mUndoManager groupsByEvent])
    					[mUndoManager endUndoGrouping];
				}
			}
		}
    }
    BXHandleError (error, localError);
    return objectIDs;
}

- (BOOL) checkDatabaseURI: (NSError **) error
{
	BOOL rval = YES;
	BXAssertLog (NULL != error, @"Expected error not to be null.");
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
		
		if (NULL != error)
			*error = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorNoDatabaseURI userInfo: userInfo];
	}
	return rval;
}

- (id <BXInterface>) databaseInterface
{
	if (nil == mDatabaseInterface)
	{
		mDatabaseInterface = [[[[self class] interfaceClassForScheme: 
            [mDatabaseURI scheme]] alloc] initWithContext: self];
		[mDatabaseInterface setAutocommits: mAutocommits];
	}
	return mDatabaseInterface;
}

- (void) lazyInit
{
	if (nil == mUndoManager)
		mUndoManager = [[NSUndoManager alloc] init];
		
	if (nil == mObjects)
	{
		mObjects = [MKCDictionary copyDictionaryWithKeyType: kMKCCollectionTypeObject
												  valueType: kMKCCollectionTypeWeakObject];
	}
	
	if (nil == mModifiedObjectIDs)
        mModifiedObjectIDs = CFDictionaryCreateMutable (NULL, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
	
	if (nil == mUndoGroupingLevels)
		mUndoGroupingLevels = [[NSMutableIndexSet alloc] init];
	
	if (YES == mUsesKeychain && NULL == mKeychainPasswordItem)
        [self fetchPasswordFromKeychain];	    
}

+ (void) loadedAppKitFramework
{
	gHaveAppKitFramework = YES;
}

- (void) setDatabaseURIInternal: (NSURL *) uri
{
	if (uri != mDatabaseURI)
    {
        if (nil != uri && [self checkURIScheme: uri error: NULL])
		{
			[mDatabaseURI release];
			mDatabaseURI = [uri retain];
		}
    }	
}

- (NSArray *) keyPathComponents: (NSString *) keyPath
{
    return [mDatabaseInterface keyPathComponents: keyPath];
}

- (void) faultKeys: (NSArray *) keys inObjectsWithIDs: (NSArray *) ids
{
    TSEnumerate (currentObject, e, [[self registeredObjectsWithIDs: ids] objectEnumerator])
    {
        if ([NSNull null] != currentObject)
        {
            if (nil == keys)
                [currentObject faultKey: nil];
            else
            {
                TSEnumerate (currentKey, e, [keys objectEnumerator])
                    [currentObject faultKey: currentKey];
            }
        }
    }
}

- (void) setConnectionSetupManager: (id <BXConnectionSetupManager>) anObject
{
	if (mConnectionSetupManager != anObject)
	{
		[mConnectionSetupManager release];
		mConnectionSetupManager = [anObject retain];
	}
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
        if (mRetainRegisteredObjects)
            [anObject retain];
    }
    return rval;
}

- (void) unregisterObject: (BXDatabaseObject *) anObject
{
    if (mRetainRegisteredObjects) {
        [[mObjects objectForKey: [anObject objectID]] autorelease];
    }
    [mObjects removeObjectForKey: [anObject objectID]];
}

- (void) setCanConnect: (BOOL) aBool
{
	if (aBool != mCanConnect)
	{
		[self willChangeValueForKey: @"canConnect"];
		mCanConnect = aBool;
		[self didChangeValueForKey: @"canConnect"];
	}
}

- (BXEntityDescription *) entityForTable: (NSString *) tableName inSchema: (NSString *) schemaName 
                     validateImmediately: (BOOL) validateImmediately error: (NSError **) error
{
    NSError* localError = nil;
    BXEntityDescription* retval = nil;
    if ([self checkDatabaseURI: &localError])
    {
        retval = [BXEntityDescription entityWithDatabaseURI: mDatabaseURI
													  table: tableName
												   inSchema: schemaName];
		[mEntities addObject: retval];
        
        if (! [retval isValidated])
        {
            if (validateImmediately)
            {
                [self connectIfNeeded: &localError];
                if (nil == localError)
                    [self validateEntity: retval error: &localError];
                [self iterateValidationQueue: &localError];
            }
            else
            {
                //Return an entity which will be validated later.
                if (nil == mLazilyValidatedEntities)
                    mLazilyValidatedEntities = [[NSMutableSet alloc] init];
                
                [mLazilyValidatedEntities addObject: retval];            
            }
        }
    }
    
    BXHandleError (error, localError);
    if (nil != localError)
        retval = nil;
    
    return retval;
}

- (void) iterateValidationQueue: (NSError **) error
{
    BXAssertVoidReturn (NULL != error, @"Expected error to be set.");
    while (0 < [mLazilyValidatedEntities count])
    {
        NSSet* entities = [[mLazilyValidatedEntities copy] autorelease];
        [mLazilyValidatedEntities removeAllObjects];
        TSEnumerate (currentEntity, e, [entities objectEnumerator])
        {
            [self validateEntity: currentEntity error: error]; //FIXME: possible bottleneck.
            if (nil != *error)
            {
                //Remember the remaining objects.
                [mLazilyValidatedEntities addObjectsFromArray: [e allObjects]];
                return;
            }
        }
    }
}

- (NSSet *) relationshipsForEntity: (BXEntityDescription *) anEntity error: (NSError **) error
{
	NSError* localError = nil;
	id relationships = nil;
	if ([self checkDatabaseURI: &localError])
	{		
		[self connectIfNeeded: &localError];
		if (nil == error)
			relationships = [mDatabaseInterface relationshipsForEntity: anEntity error: &localError];
		BXHandleError (NULL, localError);
	}
	return relationships;
}

- (void) validateEntity: (BXEntityDescription *) entity error: (NSError **) error
{
	//This should be safe even with multiple threads.

	BXAssertVoidReturn (NULL != error, @"Expected error not to be NULL.");
	if (! [entity isValidated])
	{
		NSLock* lock = [entity validationLock];
		[lock lock];
		//Check again in case someone else had the lock.
		if (! [entity isValidated])
		{
			//Even if an entity has already been validated, allow a database interface to do something with it.
			[mDatabaseInterface validateEntity: entity error: error];
			if (nil == *error)
			{
				if (! [entity isValidated])
				{
					if (! [entity hasCapability: kBXEntityCapabilityRelationships])
						[entity setValidated: YES];
					else
					{
						NSDictionary* relationships = [mDatabaseInterface relationshipsForEntity: entity error: error];
						if (nil == *error)
						{
							[entity setRelationships: relationships];
							[entity setValidated: YES];
						}
						
						if ([entity isValidated])
							[mRelationships addObjectsFromArray: [[entity relationshipsByName] allValues]];
					}			
				}
			}
		}
		
		[lock unlock];
	}
}

- (BOOL) checkURIScheme: (NSURL *) url error: (NSError **) error
{
	//FIXME: set error instead of raising an exception.
	BOOL retval = YES;
    if (Nil == [[self class] interfaceClassForScheme: [url scheme]])
    {
		retval = NO;
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  self,   kBXDatabaseContextKey,
								  url,    kBXURIKey,
								  nil];
        @throw [NSException exceptionWithName: kBXUnsupportedDatabaseException 
                                       reason: nil
                                     userInfo: userInfo];
    }
	return retval;
}

- (BOOL) checkErrorHandling
{
	BOOL retval = YES;
	switch (mConnectionErrorHandlingState) 
	{
		case kBXConnectionErrorResolving:
			bx_query_during_reconnect ();
			//Fall through.
			
		case kBXConnectionErrorNoReconnect:
			retval = NO;
			break;
			
		case kBXConnectionErrorNone:
		default:
			break;
	}
	return retval;
}

- (void) setAllowReconnecting: (BOOL) shouldAllow
{
	mConnectionErrorHandlingState = (shouldAllow ? kBXConnectionErrorNone : kBXConnectionErrorNoReconnect);
}
@end


@implementation BXDatabaseContext (Keychain)

static SecKeychainAttribute
KeychainAttribute (SecItemAttr tag, void* value, UInt32 length)
{
    SecKeychainAttribute attribute;
    bzero (&attribute, sizeof (SecKeychainAttribute));
    attribute.tag = tag;
    attribute.data = value;
    attribute.length = length;
    return attribute;
}

static BOOL
ConditionalKeychainAttributeFromString (SecItemAttr tag, NSString* value, SecKeychainAttribute* attribute)
{
    BOOL rval = NO;
    if (nil != value)
    {
        bzero (attribute, sizeof (SecKeychainAttribute));
        const char* utfValue = [value UTF8String];
        attribute->tag = tag;
        attribute->data = (void **) utfValue;
        attribute->length = strlen (utfValue);
        rval = YES;
    }
    return rval;
}

static void
AddKeychainAttributeString (SecItemAttr tag, NSString* value, NSMutableData* buffer)
{
    SecKeychainAttribute attribute;
    if (ConditionalKeychainAttributeFromString (tag, value, &attribute))
    {
        [buffer appendBytes: &attribute length: sizeof (SecKeychainAttribute)];
    }
}

static void
AddKeychainAttribute (SecItemAttr tag, void* value, UInt32 length, NSMutableData* buffer)
{
    SecKeychainAttribute attribute = KeychainAttribute (tag, value, length);
    [buffer appendBytes: &attribute length: sizeof (SecKeychainAttribute)];
}

- (NSArray *) keychainItems
{
    OSStatus status = noErr;
    NSMutableArray* rval = nil;
    
    NSMutableData* attributeBuffer = [NSMutableData data];
    AddKeychainAttributeString (kSecAccountItemAttr, [mDatabaseURI user], attributeBuffer);
    AddKeychainAttributeString (kSecServerItemAttr,  [mDatabaseURI host], attributeBuffer);
    AddKeychainAttributeString (kSecPathItemAttr,    [mDatabaseURI path], attributeBuffer);

    SecAuthenticationType authType = kSecAuthenticationTypeDefault;
    AddKeychainAttribute (kSecAuthenticationTypeItemAttr, &authType, 
                          sizeof (SecAuthenticationType), attributeBuffer);

    //FIXME: For some reason we can't look for only non-invalid items
#if 0
    Boolean allowNegative = FALSE;
    AddKeychainAttribute (kSecNegativeItemAttr, &allowNegative, sizeof (Boolean), attributeBuffer);
#endif
    
    NSNumber* portObject = [mDatabaseURI port];
    UInt32 port = (portObject ? [portObject unsignedIntValue] : 5432);
    AddKeychainAttribute (kSecPortItemAttr, &port, sizeof (UInt32), attributeBuffer);
    
    //FIXME: Do we also need the creator code? Does the current application have one?
    SecKeychainAttributeList attrList = {
        .count = ([attributeBuffer length] / sizeof (SecKeychainAttribute)), 
        .attr = (void *) [attributeBuffer bytes]
    };
    SecKeychainSearchRef search = NULL;
    status = SecKeychainSearchCreateFromAttributes (NULL, //Default keychain
                                                    kSecInternetPasswordItemClass,
                                                    &attrList,
                                                    &search);
    if (noErr == status)
    {
        rval = [NSMutableArray array];
        SecKeychainItemRef item = NULL;
        while (noErr == SecKeychainSearchCopyNext (search, &item))
            [rval addObject: (id) item];
        CFRelease (search);
    }
    
    return rval;
}

- (SecKeychainItemRef) newestKeychainItem
{
    SecKeychainItemRef rval = NULL;
    UInt32 rvalModDate = 0;
    SecItemAttr attributes [] = {kSecModDateItemAttr, kSecNegativeItemAttr};
    SecExternalFormat formats [] = {kSecFormatUnknown, kSecFormatUnknown};
    unsigned int count = sizeof (attributes) / sizeof (SecItemAttr);
	BXAssertValueReturn (count == sizeof (formats) / sizeof (SecExternalFormat), NULL,
						   @"Expected arrays to have an equal number of items.");
    SecKeychainAttributeInfo info = {count, (void *) attributes, (void *) formats};
    
    TSEnumerate (currentItem, e, [[self keychainItems] objectEnumerator])
    {
        SecKeychainItemRef item = (SecKeychainItemRef) currentItem;        
        OSStatus status = noErr;
        SecKeychainAttributeList* returnedAttributes = NULL;
        status = SecKeychainItemCopyAttributesAndData (item, &info, NULL, &returnedAttributes, NULL, NULL);
        //kSecNegativeItemAttr's data seems to be NULL at least when the attribute hasn't been set.
        if (noErr == status && NULL != returnedAttributes &&
            NULL == returnedAttributes->attr [1].data)
        {
            UInt32* datePtr = returnedAttributes->attr [0].data;
            UInt32 modDate = *datePtr;
            if (modDate > rvalModDate)
                rval = item;
            SecKeychainItemFreeAttributesAndData (returnedAttributes, NULL);
        }
    }
    return rval;
}

- (BOOL) fetchPasswordFromKeychain
{
    BOOL rval = NO;
    [self setKeychainPasswordItem: [self newestKeychainItem]];
    if (NULL != mKeychainPasswordItem)
    {
        SecItemAttr attributes [] = {kSecAccountItemAttr};
        SecExternalFormat formats [] = {kSecFormatUnknown};
        unsigned int count = sizeof (attributes) / sizeof (SecItemAttr);
		unsigned int formatCount = sizeof (formats) / sizeof (SecExternalFormat);
        BXAssertValueReturn (count == formatCount, NO,
							   @"Expected arrays to have an equal number of items (attributes: %u formats: %u).", count, formatCount);
        SecKeychainAttributeInfo info = {count, (void *) attributes, (void *) formats};
        
        OSStatus status = noErr;
        SecKeychainAttributeList* returnedAttributes = NULL;
        UInt32 passwordLength = 0;        
        char* passwordData = NULL;
        status = SecKeychainItemCopyAttributesAndData (mKeychainPasswordItem, &info, NULL, &returnedAttributes, 
                                                       &passwordLength, (void **) &passwordData);
        if (noErr == status && 0 < returnedAttributes->count)
        {
            SecKeychainAttribute usernameAttribute = returnedAttributes->attr [0];
            NSString* username = [[[NSString alloc] initWithBytes: usernameAttribute.data
                                                           length: usernameAttribute.length
                                                         encoding: NSUTF8StringEncoding] autorelease];
            NSString* password = [[[NSString alloc] initWithBytes: passwordData
                                                           length: passwordLength
                                                         encoding: NSUTF8StringEncoding] autorelease];
            
            [self setDatabaseURIInternal: [mDatabaseURI BXURIForHost: nil
															database: nil 
															username: username
															password: password]];
            SecKeychainItemFreeAttributesAndData (returnedAttributes, passwordData);
            rval = YES;
        }
    }    
    return rval;
}

- (void) clearKeychainPasswordItem
{
    [self setKeychainPasswordItem: NULL];
}

- (void) setKeychainPasswordItem: (SecKeychainItemRef) anItem
{
    if (anItem != mKeychainPasswordItem)
    {
        if (NULL != mKeychainPasswordItem)
            CFRelease (mKeychainPasswordItem);
        
		mKeychainPasswordItem = anItem;
		
		if (NULL != mKeychainPasswordItem)
            CFRetain (mKeychainPasswordItem);
    }
}

@end


@implementation BXDatabaseContext (Callbacks)
- (void) BXConnectionSetupManagerFinishedAttempt
{
	if (NO == [self isConnected])
		[self setCanConnect: YES];
}
@end


@implementation BXDatabaseContext (DefaultErrorHandler)
- (void) BXDatabaseContext: (BXDatabaseContext *) context 
				  hadError: (NSError *) error 
			willBePassedOn: (BOOL) willBePassedOn;
{
	if (! willBePassedOn)
		@throw [error BXExceptionWithName: kBXExceptionUnhandledError];
}

- (void) BXDatabaseContext: (BXDatabaseContext *) context lostConnection: (NSError *) error
{
	if (gHaveAppKitFramework)
	{
		mConnectionErrorHandlingState = kBXConnectionErrorResolving;
		//FIXME: do something about this; not just logging.
		if ([NSApp presentError: error])
			NSLog (@"Reconnected.");
		else
			NSLog (@"Failed to reconnect.");
	}
	else
	{
		@throw [error BXExceptionWithName: kBXExceptionUnhandledError];
	}
}
@end
