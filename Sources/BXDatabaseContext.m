//
// BXDatabaseContext.m
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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

#import "PGTSCFScannedMemoryAllocator.h"
#import "PGTSCollections.h"
#import "PGTSHOM.h"

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
#import "BXLogger.h"
#import "BXProbes.h"
#import "BXDelegateProxy.h"
#import "BXDatabaseContextDelegateDefaultImplementation.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXEnumerate.h"
#import "BXLocalizedString.h"
#import "BXDatabaseObjectModel.h"
#import "BXDatabaseObjectModelStorage.h"
#import "BXAttributeDescriptionPrivate.h"
#import "BXError.h"
#import "BXForeignKey.h"
#import "BXArraySize.h"

#import "NSURL+BaseTenAdditions.h"


__strong static NSMutableDictionary* gInterfaceClassSchemes = nil;
static BOOL gHaveAppKitFramework = NO;


#define BXHandleError( ERROR, LOCAL_ERROR ) BXHandleError2( self, mDelegateProxy, ERROR, LOCAL_ERROR )

static void
BXHandleError2 (id ctx, id <BXDatabaseContextDelegate> delegateProxy, NSError **error, NSError *localError)
{
    if (nil != localError)
    {
        BOOL haveError = (NULL != error);
        [delegateProxy databaseContext: ctx hadError: localError willBePassedOn: haveError];
        if (haveError)
            *error = localError;
    }
}

static NSMutableDictionary*
ObjectIDsByEntity (NSArray *ids)
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    BXEnumerate (objectID, e, [ids objectEnumerator])
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
AddObjectIDsForInheritance2 (NSMutableDictionary *idsByEntity, BXEntityDescription* entity)
{
    id subEntities = [entity subEntities];
    BXEnumerate (currentEntity, e, [subEntities objectEnumerator])
    {
        NSMutableArray* subIds = [idsByEntity objectForKey: currentEntity];
        if (nil == subIds)
        {
            subIds = [NSMutableArray array];
            [idsByEntity setObject: subIds forKey: currentEntity];
        }
        
        //Create the corresponding ids.
        BXEnumerate (objectID, e, [[idsByEntity objectForKey: entity] objectEnumerator])
        {
			NSDictionary* pkeyFields = nil;
			BOOL parsed = [BXDatabaseObjectID parseURI: [objectID URIRepresentation]
												entity: NULL
												schema: NULL
									  primaryKeyFields: &pkeyFields];
			BXAssertVoidReturn (parsed, @"Expected object URI to be parseable.");
			if (! parsed) break;
			
            BXDatabaseObjectID* newID = [BXDatabaseObjectID IDWithEntity: currentEntity primaryKeyFields: pkeyFields];
            [subIds addObject: newID];
            [newID release];
        }
        AddObjectIDsForInheritance2 (idsByEntity, currentEntity);
    }    
}

static void
AddObjectIDsForInheritance (NSMutableDictionary *idsByEntity)
{
    BXEnumerate (entity, e, [[idsByEntity allKeys] objectEnumerator])
        AddObjectIDsForInheritance2 (idsByEntity, entity);
}

static void
bx_query_during_reconnect ()
{
	BXLogError (@"Tried to send a query during reconnection attempt.");
	BXLogInfo (@"Break on bx_query_during_reconnect to inspect.");
}


static enum BXModificationType
ObjectToModType (NSValue* value)
{
    enum BXModificationType retval = kBXNoModification;
    [value getValue: &retval];
    return retval;
}


static NSValue*
ModTypeToObject (enum BXModificationType value)
{
    return [NSValue valueWithBytes: &value objCType: @encode (enum BXModificationType)];
}


/** 
 * \brief The database context. 
 *
 * A database context connects to a given database, sends queries and commands to it and
 * creates objects from rows in its tables. In order to function properly, it needs an URI formatted 
 * like pgsql://username:password\@hostname/database_name/.
 *
 * Various methods of this class take an NSError parameter. If the parameter isn't set, the context
 * will handle errors by throwing a BXException named \em kBXFailedToExecuteQueryException. 
 * See BXDatabaseContextDelegate::databaseContext:hadError:willBePassedOn:.
 *
 * \note This class is not thread-safe, i.e. 
 *		 if methods of a BXDatabaseContext instance will be called from 
 *		 different threads the result is undefined and deadlocks are possible.
 * \ingroup baseten
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
		
		PGTSScannedMemoryAllocator ();
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
 * \brief A convenience method.
 * \param   uri     URI of the target database
 * \return          The database context
 * \throw   NSException named \em kBXUnsupportedDatabaseException in case the given URI cannot be handled.
 */
+ (id) contextWithDatabaseURI: (NSURL *) uri
{
    return [[[self alloc] initWithDatabaseURI: uri] autorelease];
}

/**
 * \brief An initializer.
 *
 * The database URI has to be set afterwards.
 * \return          The database context
 */
- (id) init
{
    return [self initWithDatabaseURI: nil];
}

/**
 * \brief The designated initializer.
 * \param   uri     URI of the target database
 * \return          The database context
 * \throw           NSException named \em kBXUnsupportedDatabaseException in case the given URI cannot be handled.
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
		mSendsLockQueries = YES;
		mUsesKeychain = YES;
		
		mDelegateProxy = [[BXDelegateProxy alloc] initWithDelegateDefaultImplementation:
						  [[[BXDatabaseContextDelegateDefaultImplementation alloc] init] autorelease]];
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
    
	[mObjectModel release];
    [mDatabaseInterface release];
    [mDatabaseURI release];
    [mObjects release];
    [mModifiedObjectIDs release];
    [mUndoManager release];
	[mUndoGroupingLevels release];
	[mConnectionSetupManager release];
    [mNotificationCenter release];
	[mDelegateProxy release];
	[mLastConnectionError release];
    
    if (NULL != mKeychainPasswordItem)
        CFRelease (mKeychainPasswordItem);
    
    BXLogDebug (@"Deallocating BXDatabaseContext");
    [super dealloc];
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
 * \brief Set whether the receiver should retain all registered objects.
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

- (BOOL) connectIfNeeded: (NSError **) error
{
	return [self connectSync: error];
}

/** \name Connecting and disconnecting */
//@{
/**
 * \brief Set the database URI.
 *
 * Also clears the context's strong references to entity descriptions received from it.
 * \param   uri     The database URI
 * \throw   NSException named \em kBXUnsupportedDatabaseException in case the given URI cannot be handled.
 */
- (void) setDatabaseURI: (NSURL *) uri
{
	[self setKeychainPasswordItem: NULL];
	if (! [[uri scheme] isEqual: [mDatabaseURI scheme]])
	{
		[self setDatabaseInterface: nil];
		[self databaseInterface];
	}

	if (mDatabaseURI && 0 < [[mDatabaseURI host] length])
		[self setDatabaseObjectModel: nil];
	
	[self setDatabaseURIInternal: uri];

	if (0 < [[mDatabaseURI host] length])
	{
		[self databaseObjectModel];

		[[self internalDelegate] databaseContextGotDatabaseURI: self];
		NSNotificationCenter* nc = [self notificationCenter];
		[nc postNotificationName: kBXGotDatabaseURINotification object: self];	
	}
}

/**
 * \brief The database URI.
 */
- (NSURL *) databaseURI
{
    return mDatabaseURI;
}

/**
 * \brief Whether connection is attempted on -awakeFromNib.
 */
- (BOOL) connectsOnAwake
{
	return mConnectsOnAwake;
}

/**
 * \brief Set whether connection should be attempted on -awakeFromNib.
 */
- (void) setConnectsOnAwake: (BOOL) aBool
{
	mConnectsOnAwake = aBool;
}

/**
 * \brief Establishing a connection.
 *
 * Returns a boolean indicating whether connecting can be attempted using -connect:.
 * Presently this method returns YES when connection attempt hasn't already been started and after
 * the attempt has failed.
 */
- (BOOL) canConnect
{
	return mCanConnect;
}

/**
 * \brief Connection status.
 */
- (BOOL) isConnected
{
	return [[self databaseInterface] connected];
}

/**
 * \brief Connect to the database.
 *
 * This method returns after the connection has been made.
 */
- (BOOL) connectSync: (NSError **) error
{
	BOOL retval = NO;
    NSError* localError = nil;
	mDidDisconnect = NO;
	if ([self isConnected])
		retval = YES;
	else if ([self checkDatabaseURI: &localError])
	{
		[self setCanConnect: NO];
		[self lazyInit];
		retval = [[self databaseInterface] connectSync: &localError];
		retval = [self connectedToDatabase: retval async: NO error: &localError];
		
		if (! retval)
		{
			[mDatabaseInterface release];
			mDatabaseInterface = nil;
		}
	}
    BXHandleError (error, localError);
	return retval;
}

/**
 * \brief Connect to the database.
 *
 * Hand over the connection setup to \em mConnectionSetupManager. In BaseTenAppKit 
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
 * \brief Connect to the database.
 *
 * This method returns immediately.
 * After the attempt, either a \em kBXConnectionSuccessfulNotification or a 
 * \em kBXConnectionFailedNotification will be posted to the context's
 * notification center.
 */
- (void) connectAsync
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
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObject: localError forKey: kBXErrorKey];
        NSNotification* notification = [NSNotification notificationWithName: kBXConnectionFailedNotification object: self userInfo: userInfo];
		[mDelegateProxy databaseContext: self failedToConnect: localError];
        [[self notificationCenter] postNotification: notification];
	}	
}

/**
 * \brief Disconnect from the database.
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
 * \brief Set the query execution method.
 *
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
 * \brief Query execution method
 * \return          A BOOL indicating whether or not autocommit is in use.
 */
- (BOOL) autocommits
{
    return mAutocommits;
}

/**
 * \brief Set whether the context should mark rows locked after editing.
 *
 * Makes the receiver send notifications to other BaseTen clients
 * about updated or deleted rows being locked when the receiver
 * has an ongoing transaction. This causes some additional queries to
 * be sent. The context may still receive lock notifications from other 
 * contexts.
 * \see BXDatabaseObject::isLockedForKey:
 * \see BXSynchronizedArrayController::setLocksRowsOnBeginEditing:
 */
- (void) setSendsLockQueries: (BOOL) aBool
{
	if ([mDatabaseInterface connected])
		[NSException raise: NSInvalidArgumentException format: @"Lock mode cannot be set after connecting."];
	mSendsLockQueries = aBool;
}

/**
 * \brief Whether the context tries to lock rows after editing.
 */
- (BOOL) sendsLockQueries
{
	return mSendsLockQueries;
}

/**
 * \brief The undo manager used by this context.
 */
- (NSUndoManager *) undoManager
{
    return mUndoManager;
}

/**
 * \brief Set the undo manager used by the context.
 *
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
 * \brief Rollback the transaction ina manual commit mode.
 *
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
        BXEnumerate (currentID, e, [(id) mModifiedObjectIDs keyEnumerator])
        {
			BXDatabaseObject* registeredObject = [self registeredObjectWithID: currentID];
            switch (ObjectToModType ([mModifiedObjectIDs objectForKey: currentID]))
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
 * \brief Commit the current transaction in manual commit mode.
 *
 * Undo will be disabled after this.
 * \return      A boolean indicating whether the commit was successful or not.
 */
- (BOOL) save: (NSError **) error
{
    BOOL retval = YES;
    if ([self checkErrorHandling] && NO == [mDatabaseInterface autocommits])
    {
        NSError* localError = nil;
        BXEnumerate (currentID, e, [(id) mModifiedObjectIDs keyEnumerator])
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
 * \brief Commit the changes.
 * \param sender Ignored.
 * \throw BXException named \em kBXFailedToExecuteQueryException if commit fails.
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
 * \brief Rollback the changes.
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
 * \brief Objects with given IDs.
 *
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
        BXEnumerate (currentID, e, [anArray objectEnumerator])
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
 * \brief Retrieve a registered database object.
 *
 * Looks up an object from the cache. The database is not queried in any case.
 * \return The cached object or nil.
 */
- (BXDatabaseObject *) registeredObjectWithID: (BXDatabaseObjectID *) objectID
{
    return [mObjects objectForKey: objectID];
}

/**
 * \brief Retrieve registered database objects.
 *
 * Looks up objects from the cache. The database is not queried in any case.
 * \param objectIDs         The object IDs to look for.
 * \return An NSArray of cached objects and NSNulls.
 */
- (NSArray *) registeredObjectsWithIDs: (NSArray *) objectIDs
{
    return [self registeredObjectsWithIDs: objectIDs nullObjects: YES];
}

/**
 * \brief Retrieve registered database objects.
 *
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
        BXEnumerate (currentObject, e, [rval objectEnumerator])
        {
            if (nullObject != currentObject)
                [objects addObject: currentObject];
        }
        rval = objects;
    }
    return rval;
}
//@}


/** 
 * \brief The delegate. 
 */
- (id <BXDatabaseContextDelegate>) delegate
{
	return delegate;
}

/**
 * \brief Set the delegate.
 *
 * The delegate object will not be retained.
 */
- (void) setDelegate: (id <BXDatabaseContextDelegate>) anObject;
{
	delegate = anObject;
	[(BXDelegateProxy *) mDelegateProxy setDelegateForBXDelegateProxy: delegate];
}

/** \name Using the Keychain */
//@{
/**
 * \brief Whether the default keychain is searched for database passwords.
 */
- (BOOL) usesKeychain
{
    return mUsesKeychain;
}

/**
 * \brief Set whether the default keychain should be searched for database passwords.
 */
- (void) setUsesKeychain: (BOOL) usesKeychain
{
	mUsesKeychain = usesKeychain;
}

/** \brief Whether a known-to-work password will be stored into the default keychain. */
- (BOOL) storesURICredentials
{
	return mShouldStoreURICredentials;
}

/** \brief Set whether a known-to-work password should be stored into the default keychain. */
- (void) setStoresURICredentials: (BOOL) shouldStore
{
	mShouldStoreURICredentials = shouldStore;
}
//@}

/**
 * \internal
 * \brief Store login credentials from the database URI to the default keychain.
 */
- (void) storeURICredentials
{
    OSStatus status = noErr;
    const char* serverName = [[mDatabaseURI host] UTF8String];
    const char* username = [[mDatabaseURI user] UTF8String];
    const char* path = [[mDatabaseURI path] UTF8String];    
    NSNumber* portObject = [mDatabaseURI port];
    UInt16 port = (portObject ? [portObject unsignedShortValue] : 5432U);
    
    const char* password = [[mDatabaseURI password] UTF8String];
	if (! (password && [mDatabaseInterface usedPassword]))
    	password = "";
    
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
												 strlen (password), password, 
												 &item);
		[self setKeychainPasswordItem: item];
	}
	
	if (errSecDuplicateItem == status || (NULL == item && NULL != mKeychainPasswordItem))
	{
		status = SecKeychainItemModifyAttributesAndData (mKeychainPasswordItem, NULL, strlen (password), password);
	}
	
	if (noErr == status)
	{
		[self setKeychainPasswordItem: NULL];
	}
}

/** \name Faulting database objects */
//@{
/**
 * \brief Refresh or fault an object.
 *
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
 * \brief The notification center for this context.
 *
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
/** \brief The NSWindow used with various sheets. */
- (NSWindow *) modalWindow
{
	return modalWindow;
}

/**
 * \brief Set the NSWindow used with various sheets.
 *
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

- (void) setAllowReconnecting: (BOOL) shouldAllow
{
	mConnectionErrorHandlingState = (shouldAllow ? kBXConnectionErrorNone : kBXConnectionErrorNoReconnect);
}

/** \brief Whether SSL is currently in use. */
- (BOOL) isSSLInUse
{
	return [mDatabaseInterface isSSLInUse];
}

/** \brief Whether queries are logged to stdout. */
- (BOOL) logsQueries
{
	return [mDatabaseInterface logsQueries];
}

/** \brief Set whether queries are logged to stdout. */
- (void) setLogsQueries: (BOOL) shouldLog
{
	[mDatabaseInterface setLogsQueries: shouldLog];
}
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
			[mDelegateProxy databaseContext: self hadError: localError willBePassedOn: NO];
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
		[mDelegateProxy databaseContext: self hadError: error willBePassedOn: NO];
}

#if 0
- (void) reregisterObjects: (NSArray *) objectIDs values: (NSDictionary *) pkeyValues
{
	BXEnumerate (currentID, e, [objectIDs objectEnumerator])
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
		BXEnumerate (currentID, e, [objectIDs objectEnumerator])
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
 * \brief These methods block until the result has been retrieved.
 */
//@{
/**
 * \brief Fetch an object with a given ID.
 *
 * The database is queried only if the object isn't in cache.
 */
- (id) objectWithID: (BXDatabaseObjectID *) anID error: (NSError **) error
{
    id retval = [self registeredObjectWithID: anID];
    if (nil == retval && [self checkErrorHandling])
    {
        NSError* localError = nil;
		if (! [self connectSync: &localError])
			goto error;
		
		NSArray* objects = [self executeFetchForEntity: (BXEntityDescription *) [anID entity] 
										 withPredicate: [anID predicate] returningFaults: NO error: &localError];
		if (localError) goto error;
		
		if (0 < [objects count])
			retval = [objects objectAtIndex: 0];
		else
		{
			//FIXME: some human-readable error?
			localError = [BXError errorWithDomain: kBXErrorDomain code: kBXErrorObjectNotFound userInfo: nil];
		}
		
	error:
        BXHandleError (error, localError);
    }
    return retval;
}

/**
 * \brief Fetch objects with given IDs.
 *
 * The database is queried only if the object aren't in cache.
 */
- (NSSet *) objectsWithIDs: (NSArray *) anArray error: (NSError **) error
{
    NSMutableSet* rval = nil;
    if (0 < [anArray count])
    {
        rval = [NSMutableSet setWithCapacity: [anArray count]];
        NSMutableDictionary* entities = [NSMutableDictionary dictionary];
        BXEnumerate (currentID, e, [anArray objectEnumerator])
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
			BXEnumerate (currentEntity, e, [entities keyEnumerator])
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
 * \brief Fetch objects from the database.
 *
 * Essentially calls #executeFetchForEntity:withPredicate:returningFaults:error: with \em returningFaults set to NO.
 *  
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time.
 */
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate error: (NSError **) error
{
    return [self executeFetchForEntity: entity withPredicate: predicate returningFaults: NO error: error];
}

/**
 * \brief Fetch objects from the database.
 *
 * Instead of fetching the field values, the context can retrieve objects that
 * contain only the object ID. The other values get fetched on-demand.\n
 * Essentially calls #executeFetchForEntity:withPredicate:returningFaults:updateAutomatically:error: with \em updateAutomatically set to NO.
 *
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       returnFaults    A boolean indicating whether faults should
 *                              be returned or not.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
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
 * \brief Fetch objects from the database.
 *
 * Instead of fetching all the columns, the user may supply a list of fields
 * that are excluded from the query results. The returned objects are 
 * faults. Values for the non-excluded fields are cached, though.\n
 * Essentially calls #executeFetchForEntity:withPredicate:excludingFields:updateAutomatically:error:
 * with \em updateAutomatically set to NO.
 *
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       excludedFields  An NSArray containing the BXPropertyDescriptors for the columns
 *                              that should be excluded. May be nil.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
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
 * \brief Fetch objects from the database.
 *
 * The result array can be set to be updated automatically. 
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       returnFaults    A boolean indicating whether faults should be returned or not.
 * \param       shouldUpdate    A boolean indicating whether the results 
 *                              should be updated by the context or not.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time, or a BXArrayProxy.
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
 * \brief Fetch objects from the database.
 *
 * The result array can be set to be updated automatically.
 * \param       entity          The entity from which rows are fetched.
 * \param       predicate       A WHERE clause is constructed using this predicate. May be nil.
 * \param       excludedFields  An NSArray containing the BXPropertyDescriptors for the columns
 *                              that should be excluded. May be nil.
 * \param       shouldUpdate    A boolean indicating whether the results 
 *                              should be updated by the context or not.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \return                      An NSArray that reflects the state of the database at query 
 *                              execution time, or a BXArrayProxy.
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
 * \brief Create a new database object.
 *
 * Essentially inserts a new row into the database and retrieves it.
 * \param       entity           The target entity.
 * \param       givenFieldValues Initial values for fields. May be nil or left empty if
 *                               values for the primary key can be determined by the database.
 * \param       error            If an error occurs, this pointer is set to an NSError instance.
 *                               May be NULL.
 * \return                       A subclass of BXDatabaseObject or nil, if an error has occured.
 */
- (id) createObjectForEntity: (BXEntityDescription *) entity 
             withFieldValues: (NSDictionary *) givenFieldValues 
                       error: (NSError **) error
{
    NSError* localError = nil;
    BXDatabaseObject* retval = nil;
	if ([self checkErrorHandling] && [self checkDatabaseURI: &localError])
	{
		if ([self connectSync: &localError])
		{
			//The interface wants only attribute descriptions as keys
			NSDictionary* properties = [entity propertiesByName];
			NSMutableDictionary* changedObjectsByRelationship = [NSMutableDictionary dictionaryWithCapacity: [givenFieldValues count]];
			NSMutableDictionary* fieldValues = [NSMutableDictionary dictionaryWithCapacity: [givenFieldValues count]];
			BXEnumerate (currentKey, e, [givenFieldValues keyEnumerator])
			{
				id value = [givenFieldValues objectForKey: currentKey];
				if ([currentKey isKindOfClass: [NSString class]])
				{
					NSString* oldValue = currentKey;
					currentKey = [properties objectForKey: currentKey];
					BXAssertValueReturn (currentKey, nil, @"Key %@ wasn't known.", oldValue);
				}
				else
				{
					BXAssertValueReturn ([currentKey isKindOfClass: [BXPropertyDescription class]],
										 @"Expected %@ to be either a string or a property description.", currentKey);
				}
				
				switch ([currentKey propertyKind])
				{
					case kBXPropertyKindAttribute:
						[fieldValues setObject: value forKey: currentKey];
						break;
						
					case kBXPropertyKindRelationship:
					{
						BXAssertValueReturn (![currentKey isToMany], nil, 
											 @"%@ was specified in value dictionary, but only to-one relationships are allowed.",
											 [currentKey name]);
						BXAssertValueReturn ([currentKey isInverse], nil,
											 @"%@ was specified in value dictionary, but its foreign key columns don't exist in %@.",
											 [currentKey name], entity);
						
						if ([value isKindOfClass: [BXDatabaseObjectID class]])
						{
							value = [[self faultsWithIDs: [NSArray arrayWithObject: value]] lastObject];
							BXAssertValueReturn (value, nil, @"Couldn't get object for object id %@.",
												 [givenFieldValues objectForKey: currentKey]);
						}
						
						NSDictionary* values = BXFkeySrcDictionary ([currentKey foreignKey], entity, value);
						[fieldValues addEntriesFromDictionary: values];
						
						[value willChangeValueForKey: [currentKey name]];
						[changedObjectsByRelationship setObject: value forKey: currentKey];
						break;
					}
						
					default:
						BXLogWarning (@"Got a strange key in values dictionary: %@", currentKey);
						break;
				}				
			}
			
			//First make the object
			retval = [mDatabaseInterface createObjectForEntity: entity withFieldValues: fieldValues
													   class: [entity databaseObjectClass]
													   error: &localError];
			
			//Then use the values received from the database with the redo invocation
			if (nil != retval && nil == localError)
			{
				//FIXME: when refactoring different commit modes out of BXDatabaseContext, rethink handling of creating and deleting objects within transactions.
                //If registration fails, there should be a suitable object in memory.
				//In that case, we'll probably want to empty the value cache.
				if (NO == [retval registerWithContext: self entity: entity])
				{
					retval = [self registeredObjectWithID: [retval objectID]];
					[retval setCachedValuesForKeysWithDictionary: nil];
				}
				BXDatabaseObjectID* objectID = [retval objectID];
				Expect (objectID);
				
				//Cache some of the values we got earlier.
				{
					NSMutableDictionary* valuesByName = [NSMutableDictionary dictionaryWithCapacity: [fieldValues count]];
					BXEnumerate (currentKey, e, [fieldValues keyEnumerator])
					{
						id value = [fieldValues objectForKey: currentKey];
						NSString* name = [currentKey name];
						
						//NSStrings get special treatment.
						if ([value isKindOfClass: [NSString class]])
							value = [value decomposedStringWithCanonicalMapping];
						
						[valuesByName setObject: value forKey: name];
					}
					[valuesByName addEntriesFromDictionary: [retval cachedValues]];
					[retval setCachedValuesForKeysWithDictionary: valuesByName];
				}
				
				if (YES == [mDatabaseInterface autocommits])
				{
					[retval awakeFromInsertIfNeeded];
					if (! [entity getsChangedByTriggers])
						[self addedObjectsToDatabase: [NSArray arrayWithObject: objectID]];
				}
				else
				{
					[retval setCreatedInCurrentTransaction: YES];
					BOOL createdSavepoint = [self prepareSavepointIfNeeded: &localError];
					if (nil == localError)
					{
						[retval awakeFromInsertIfNeeded];

						//This is needed for self-updating collections. See the deletion method.
						[self addedObjectsToDatabase: [NSArray arrayWithObject: objectID]];
						
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
						[[mUndoManager prepareWithInvocationTarget: mModifiedObjectIDs] setObject: [mModifiedObjectIDs objectForKey: objectID] 
                                                                                           forKey: objectID];
						if (![mUndoManager groupsByEvent])
    						[mUndoManager endUndoGrouping];        
						
						//Remember the modification type for ROLLBACK
                        [mModifiedObjectIDs setObject: ModTypeToObject (kBXInsertModification) forKey: objectID];
					}
				}
				
				//Call -didChangeValueForKey: for related objects that got a new target.
				BXEnumerate (currentKey, e, [changedObjectsByRelationship keyEnumerator])
				{
					BXDatabaseObject* object = [changedObjectsByRelationship objectForKey: currentKey];
					[object didChangeValueForKey: [[currentKey inverseRelationship] name]];
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
		
		if (BASETEN_BEGIN_FETCH_ENABLED ())
			BASETEN_BEGIN_FETCH ();
		
	    retval = [mDatabaseInterface fireFault: anObject keys: keys error: &localError];
		
		if (BASETEN_END_FETCH_ENABLED ())
		{
			BXEntityDescription* entity = [anObject entity];
			char* schema_s = strdup ([[entity schemaName] UTF8String]);
			char* table_s = strdup ([[entity name] UTF8String]);
			BASETEN_END_FETCH (self, schema_s, table_s, 1);
			free (schema_s);
			free (table_s);
		}
		
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
 * \brief Delete a database object.
 *
 * Essentially this method deletes a single row from the database.
 * \param       anObject        The object to be deleted.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \return                      A boolean indicating whether the deletion was successful or not.
 */
- (BOOL) executeDeleteObject: (BXDatabaseObject *) anObject error: (NSError **) error
{
    return (nil != [self executeDeleteObject: anObject entity: nil predicate: nil error: error]);
}
//@}

/** \name Executing arbitrary queries */
//@{
/**
 * \brief Execute a query directly.
 *
 * This method should only be used when fetching objects and modifying 
 * them is cumbersome or doesn't accomplish the task altogether.
 * \return An NSArray of NSDictionaries that correspond to each row.
 */
- (NSArray *) executeQuery: (NSString *) queryString error: (NSError **) error
{
	return [self executeQuery: queryString parameters: nil error: error];
}

/**
 * \brief Execute a query directly.
 *
 * This method should only be used when fetching objects and modifying 
 * them is cumbersome or doesn't accomplish the task altogether.
 * \param queryString The SQL query.
 * \param parameters An NSArray of objects that are passed as replacements for $1, $2 etc. in the query.
 * \param       error           If an error occurs, this pointer is set to an NSError instance.
 *                              May be NULL.
 * \return An NSArray of NSDictionaries that correspond to each row.
 */
- (NSArray *) executeQuery: (NSString *) queryString parameters: (NSArray *) parameters error: (NSError **) error
{
	NSError* localError = nil;
	id retval = nil;
	if ([self checkErrorHandling])
	{
		if ([self connectSync: &localError])
			retval = [mDatabaseInterface executeQuery: queryString parameters: parameters error: &localError];
		BXHandleError (error, localError);
	}
	return retval;
}

/**
 * \brief Execute a command directly.
 *
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
		if ([self connectSync: &localError])
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
	return [BXError errorWithDomain: kBXErrorDomain code: kBXErrorUnsuccessfulQuery userInfo: userInfo];	
}

- (void) connectionLost: (NSError *) error
{
	[mDelegateProxy databaseContext: self lostConnection: error];
}

//FIXME: We do too many things in this method. It should be refactored.
- (BOOL) connectedToDatabase: (BOOL) connected async: (BOOL) async error: (NSError **) error;
{
	BXAssertLog (NULL != error || (YES == async && YES == connected), @"Expected error to be set.");
	BOOL retval = connected;
	
	if (NO == connected)
	{
		[self setLastConnectionError: *error];
		if (NO == mDisplayingSheet)
		{
			//If the certificate wasn't verified, our delegate will handle the situation.
			//On any other SSL error retry the connection.
			BOOL authenticationFailed = NO;
			BOOL sslFailed = NO;
			if ([[mLastConnectionError domain] isEqualToString: kBXErrorDomain])
			{
				NSInteger code = [mLastConnectionError code];
				switch (code)
				{
					case kBXErrorAuthenticationFailed:
						authenticationFailed = YES;
						break;
						
					case kBXErrorSSLError:
					case kBXErrorSSLUnavailable:
						sslFailed = YES;
						break;
						
					case kBXErrorSSLCertificateVerificationFailed:
					default:
						break;
				}
			}
			
			if (sslFailed)
			{
				[mDatabaseInterface disconnect];
				if (async)
					[self connectAsync];
				else if ([self connectSync: error])
				{
					retval = YES;
					if (error)
						*error = nil;
				}
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
                
				//If we have a connection setup manager, it will call a method when it's finished.
				if (nil == mConnectionSetupManager)
					[self setCanConnect: YES];
				
				//Don't set the error if we were supposed to disconnect.
				NSDictionary* userInfo = nil;
				if (! mDidDisconnect && mLastConnectionError)
					userInfo = [NSDictionary dictionaryWithObject: mLastConnectionError forKey: kBXErrorKey];
				NSNotification* notification = [NSNotification notificationWithName: kBXConnectionFailedNotification object: self userInfo: userInfo];
				[mDelegateProxy databaseContext: self failedToConnect: mLastConnectionError];
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
		
		if (mShouldStoreURICredentials)
			[self storeURICredentials];

		//Strip password from the URI
		NSURL* newURI = [mDatabaseURI BXURIForHost: nil database: nil username: nil password: @""];
		[self setDatabaseURIInternal: newURI];
				
		NSNotification* notification = nil;
		if ([[self databaseObjectModel] contextConnectedUsingDatabaseInterface: mDatabaseInterface error: &localError])
		{
			[mObjectModel setCanCreateEntityDescriptions: NO];
			notification = [NSNotification notificationWithName: kBXConnectionSuccessfulNotification object: self userInfo: nil];
			if (async)
				[mDelegateProxy databaseContextConnectionSucceeded: self];
		}
		else
		{
			retval = NO;
			NSDictionary* userInfo = nil;
			[mDatabaseInterface disconnect];

			if (localError)
			{
				userInfo = [NSDictionary dictionaryWithObject: localError forKey: kBXErrorKey];
				if (NULL != error)
					*error = localError;
			}
			notification = [NSNotification notificationWithName: kBXConnectionFailedNotification object: self userInfo: userInfo];
			[mDelegateProxy databaseContext: self failedToConnect: localError];
		}
		[[self notificationCenter] postNotification: notification];
		[self setConnectionSetupManager: nil];
	}
	[self setLastConnectionError: nil];
	[self setKeychainPasswordItem: NULL];
	return retval;
}

- (NSDictionary *) targetsByObject: (NSArray *) objects forRelationships: (id) rels fireFaults: (BOOL) shouldFire
{
	NSMutableDictionary* targetsByObject = [NSMutableDictionary dictionaryWithCapacity: [objects count]];
	BXEnumerate (currentObject, e, [objects objectEnumerator])
	{
		if ([NSNull null] != currentObject)
		{
			id targets = [[rels PGTSCollectDK] registeredTargetFor: currentObject fireFault: shouldFire]; 
			if (targets)
				[targetsByObject setObject: targets forKey: currentObject];
		}
	}
	return targetsByObject;
}

//FIXME: clean me up.
- (void) updatedObjectsInDatabase: (NSArray *) objectIDs faultObjects: (BOOL) shouldFault
{
    if (0 < [objectIDs count])
    {
		NSMutableDictionary* idsByEntity = ObjectIDsByEntity (objectIDs);
		AddObjectIDsForInheritance (idsByEntity);
		NSNotificationCenter* nc = [self notificationCenter];

		BXEnumerate (entity, e, [idsByEntity keyEnumerator])
		{
			NSArray* objectIDs = [idsByEntity objectForKey: entity];
			NSArray* objects = [self registeredObjectsWithIDs: objectIDs nullObjects: YES];
			
			id rels = [entity inverseToOneRelationships];
			NSDictionary* oldTargets = nil;
			NSDictionary* newTargets = nil;
			
			if (0 < [rels count])
			{
				oldTargets = [self targetsByObject: objects forRelationships: rels fireFaults: NO];
				newTargets = [self targetsByObject: objects forRelationships: rels fireFaults: YES];
				
				BXEnumerate (currentObject, e, [objects objectEnumerator])
				{
					if ([NSNull null] != currentObject)
						[currentObject willChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
				}
			}
			
			//Fault the objects and send the notifications
			if (shouldFault)
			{
				BXEnumerate (currentObject, e, [objects objectEnumerator])
				{
					if ([NSNull null] != currentObject)
						[currentObject removeFromCache: nil postingKVONotifications: YES];
				}
			}
			
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  objectIDs, kBXObjectIDsKey,
									  objects, kBXObjectsKey,
									  self, kBXDatabaseContextKey,
									  nil];
			
			[nc postNotificationName: kBXUpdateEarlyNotification object: entity userInfo: userInfo];
			if (0 < [rels count])
			{
				BXEnumerate (currentObject, e, [objects objectEnumerator])
				{
					if ([NSNull null] != currentObject)
						[currentObject didChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
				}
			}
			
			[nc postNotificationName: kBXUpdateNotification object: entity userInfo: userInfo];
		}
    }
}

- (void) addedObjectsToDatabase: (NSArray *) objectIDs
{
    if (0 < [objectIDs count])
    {
        NSMutableDictionary* idsByEntity = ObjectIDsByEntity (objectIDs);
        AddObjectIDsForInheritance (idsByEntity);
        NSNotificationCenter* nc = [self notificationCenter];
        		
        //Post the notifications
        BXEnumerate (entity, e, [idsByEntity keyEnumerator])
        {
            NSArray* objectIDs = [idsByEntity objectForKey: entity];
			NSArray* objects = [self faultsWithIDs: objectIDs];
			
			id rels = [entity inverseToOneRelationships];
			NSDictionary* oldTargets = nil;
			NSDictionary* newTargets = nil;
			if (0 < [rels count])
			{
				oldTargets = [self targetsByObject: objects forRelationships: rels fireFaults: NO];
				newTargets= [self targetsByObject: objects forRelationships: rels fireFaults: YES];
				BXEnumerate (currentObject, e, [objects objectEnumerator])
					[currentObject willChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
			}

            //Send the notifications
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                objectIDs, kBXObjectIDsKey,
                self, kBXDatabaseContextKey,
                nil];
			
			[nc postNotificationName: kBXInsertEarlyNotification object: entity userInfo: userInfo];
			if (0 < [rels count])
			{
				BXEnumerate (currentObject, e, [objects objectEnumerator])
					[currentObject didChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
			}

			[nc postNotificationName: kBXInsertNotification object: entity userInfo: userInfo];
        }
    }
}

- (void) deletedObjectsFromDatabase: (NSArray *) objectIDs
{
	if (0 < [objectIDs count])
    {
        NSMutableDictionary* idsByEntity = ObjectIDsByEntity (objectIDs);
        AddObjectIDsForInheritance (idsByEntity);
        NSNotificationCenter* nc = [self notificationCenter];
		
        //Post the notifications
        BXEnumerate (entity, e, [idsByEntity keyEnumerator])
        {
			NSArray* objectIDs = [idsByEntity objectForKey: entity];
			id objects = [mObjects objectsForKeys: objectIDs notFoundMarker: [NSNull null]];

			BXEnumerate (currentID, e, [objectIDs objectEnumerator])
				[[self registeredObjectWithID: currentID] setDeleted: kBXObjectDeleted];
        
			id rels = [entity inverseToOneRelationships];
			NSDictionary* oldTargets = nil;
			NSDictionary* newTargets = nil;
			if (0 < [rels count])
			{
				oldTargets= [self targetsByObject: objects forRelationships: rels fireFaults: NO];
				newTargets = [self targetsByObject: objects forRelationships: rels fireFaults: YES];
				BXEnumerate (currentObject, e, [objects objectEnumerator])
				{
					if ([NSNull null] != currentObject)
						[currentObject willChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
				}
			}
        
			//Send the notifications
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  objectIDs, kBXObjectIDsKey,
									  objects, kBXObjectsKey,
									  self, kBXDatabaseContextKey,
									  nil];
			
			[nc postNotificationName: kBXDeleteEarlyNotification object: entity userInfo: userInfo];
			
			if (0 < [rels count])
			{
				BXEnumerate (currentObject, e, [objects objectEnumerator])
				{
					if ([NSNull null] != currentObject)
						[currentObject didChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
				}
			}
			
			[nc postNotificationName: kBXDeleteNotification object: entity userInfo: userInfo];
		}
	}
}
		
- (void) lockedObjectsInDatabase: (NSArray *) objectIDs status: (enum BXObjectLockStatus) status
{
    unsigned int count = [objectIDs count];
    if (0 < count)
    {
        NSMutableArray* foundObjects = [NSMutableArray arrayWithCapacity: count];
        BXEnumerate (currentID, e, [objectIDs objectEnumerator])
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
        BXEnumerate (currentObject, e, [foundObjects objectEnumerator])
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
	enum BXCertificatePolicy policy = [mDelegateProxy databaseContext: self handleInvalidTrust: trust result: result];
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
	
	enum BXCertificatePolicy policy = [mDelegateProxy databaseContext: self handleInvalidTrust: trust result: result];	
	switch (policy)
	{			
		case kBXCertificatePolicyAllow:
			[self connectAsync];
			break;
			
		case kBXCertificatePolicyDisplayTrustPanel:
			//These are in BaseTenAppKit framework.
			if (! mConnectionSetupManager)
				[self displayPanelForTrust: trust];
			else
				[mConnectionSetupManager databaseContext: self displayPanelForTrust: trust];
			
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
	enum BXSSLMode mode = [mDelegateProxy SSLModeForDatabaseContext: self];
	if ([kBXErrorDomain isEqualToString: [mLastConnectionError domain]])
	{
		if (kBXSSLModePrefer == mode)
		{
			switch ([mLastConnectionError code])
			{
				case kBXErrorSSLError:
				case kBXErrorSSLUnavailable:
				case kBXErrorSSLCertificateVerificationFailed:
					mode = kBXSSLModeDisable;
					break;
					
				default:
					break;
			}
		}
	}
	return mode;
}

- (void) networkStatusChanged: (SCNetworkConnectionFlags) newFlags
{
	[[self internalDelegate] databaseContext: self networkStatusChanged: newFlags];
}
@end


@implementation BXDatabaseContext (HelperMethods)
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
/** 
 * \brief Entity for a table in the given schema.
 * \note Unlike PostgreSQL, leaving \em schemaName unspecified does not cause the search path to be used but 
 *       instead will search the \em public schema.
 * \note Entities are associated with a database URI. Thus the database context needs an URI containing a host and 
 *       the database name before entities may be received.
 */
- (BXEntityDescription *) entityForTable: (NSString *) name inSchema: (NSString *) schemaName error: (NSError **) outError
{
	NSError* localError = nil;
	if (! schemaName) schemaName = @"public";
	id retval = [mObjectModel entityForTable: name inSchema: schemaName error: &localError];
	
	//FIXME: should this be here or in the object model?
	if (! retval && ! localError)
	{
		NSString* title = BXLocalizedString (@"databaseError", @"Database error", @"Title for a sheet");
		NSString* errorFormat = BXLocalizedString (@"relationNotFound", @"Relation %@ was not found in schema %@.", @"Error message for getting or using an entity description.");
		NSString* reason = [NSString stringWithFormat: errorFormat, name, schemaName];
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  title, NSLocalizedDescriptionKey,
								  title, NSLocalizedFailureReasonErrorKey, 
								  reason, NSLocalizedRecoverySuggestionErrorKey, 
								  self, kBXDatabaseContextKey,
								  nil];
		localError = [BXError errorWithDomain: kBXErrorDomain code: kBXErrorNoTableForEntity userInfo: userInfo];
	}
	
	BXHandleError (outError, localError);
	
	return retval;
}

/** 
 * \brief Entity for a table in the schema \em public
 * \note Entities are associated with a database URI. Thus the database context needs an URI containing a host and 
 *       the database name before entities may be received.
 */
- (BXEntityDescription *) entityForTable: (NSString *) name error: (NSError **) outError
{
	return [self entityForTable: name inSchema: nil error: outError];
}

/**
 * \brief All entities found in the database.
 *
 * Entities in private and metadata schemata won't be included.
 * \param reload Whether the entity list should be reloaded.
 * \param outError If an error occurs, this pointer is set to an NSError instance. May be NULL.
 * \return An NSDicionary with NSStrings corresponding to schema names as keys and NSDictionarys as objects. 
 *         Each of them will have NSStrings corresponding to relation names as keys and BXEntityDescriptions
 *         as objects.
 */
- (NSDictionary *) entitiesBySchemaAndName: (BOOL) reload error: (NSError **) outError
{
	NSError* localError = nil;
	NSDictionary* retval = [mObjectModel entitiesBySchemaAndName: mDatabaseInterface reload: reload error: &localError];
	[mObjectModel setCanCreateEntityDescriptions: NO];
	BXHandleError (outError, localError);
	return retval;
}
//@}

- (BOOL) entity: (NSEntityDescription *) entity existsInSchema: (NSString *) schemaName error: (NSError **) error
{
	return ([self matchingEntity: entity inSchema: schemaName error: error] ? YES : NO);
}

- (BXEntityDescription *) matchingEntity: (NSEntityDescription *) entity inSchema: (NSString *) schemaName error: (NSError **) error
{
	NSDictionary* entities = [self entitiesBySchemaAndName: NO error: error];
	return [[entities objectForKey: schemaName] objectForKey: [entity name]];
}

- (BOOL) canGiveEntities
{
	NSError* localError = nil;
	return ([self checkDatabaseURI: &localError] && [mDatabaseURI host] && [mDatabaseURI path]);
}
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
- (id <BXDatabaseContextDelegate>) internalDelegate
{
	return mDelegateProxy;
}

/** 
 * \internal
 * \brief Delete multiple objects at the same time. 
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
 * \brief Fetch objects from the database.
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
		if ([self connectSync: &localError])
		{
			if (nil != excludedFields)
			{
				excludedFields = [entity attributes: excludedFields];
				[[excludedFields PGTSDo] setExcluded: YES];
			}
			
			if (BASETEN_BEGIN_FETCH_ENABLED ())
				BASETEN_BEGIN_FETCH ();
							
			Class databaseObjectClass = [entity databaseObjectClass];
			retval = [mDatabaseInterface executeFetchForEntity: entity withPredicate: predicate 
											   returningFaults: returnFaults 
														 class: databaseObjectClass
														 error: &localError];
			
			if (BASETEN_END_FETCH_ENABLED ())
			{
				char* schema_s = strdup ([[entity schemaName] UTF8String]);
				char* table_s = strdup ([[entity name] UTF8String]);
				BASETEN_END_FETCH (self, schema_s, table_s, [retval count]);
				free (schema_s);
				free (table_s);
			}
			
			if (nil == localError)
			{
				[retval makeObjectsPerformSelector: @selector (awakeFromFetchIfNeeded)];
				
				if (Nil != returnedClass)
				{
					retval = [[[returnedClass alloc] BXInitWithArray: retval] autorelease];
					[retval setDatabaseContext: self];
					[(BXContainerProxy *) retval fetchedForEntity: entity predicate: predicate];
				}
				else if (0 == [retval count])
				{
					//If an automatically updating container wasn't requested, we might as well return nil.
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
 * \brief Update multiple objects at the same time. 
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

		//Handle KVO.
		NSArray* updatedObjects = nil;
		{
			if (anObject)
				updatedObjects = [NSArray arrayWithObject: anObject];
			else
			{
				updatedObjects = [self executeFetchForEntity: anEntity withPredicate: predicate returningFaults: YES error: &localError];
				if (localError)
					goto bail;
			}
		}
		struct update_kvo_ctx updateCtx = [self handleWillChangeForUpdate: updatedObjects newValues: aDict];
		
		objectIDs = [mDatabaseInterface executeUpdateWithDictionary: aDict objectID: [anObject objectID]
															 entity: anEntity predicate: predicate error: &localError];
		
		[self handleDidChangeForUpdate: &updateCtx newValues: aDict 
					 sendNotifications: !(localError || [mDatabaseInterface autocommits])
						  targetEntity: anEntity];
		
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
#if 0
				if (! [anEntity getsChangedByTriggers])
					[self updatedObjectsInDatabase: oldIDs faultObjects: NO];
#endif			
				
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
                    //This is needed for self-updating collections. See the deletion method.
					[self updatedObjectsInDatabase: oldIDs faultObjects: NO];
                    
                    //For redo
                    BXInvocationRecorder* recorder = [BXInvocationRecorder recorder];
                    [[recorder recordWithPersistentTarget: self] executeUpdateObject: anObject entity: anEntity 
                                                                           predicate: predicate withDictionary: aDict error: NULL];
#if 0
                    //Finally fault the object.
                    //FIXME: do we need this?
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
                    BXEnumerate (currentID, e, [objectIDs objectEnumerator])
                    {
                        enum BXModificationType modificationType = ObjectToModType ([mModifiedObjectIDs objectForKey: currentID]);
                        if (! (kBXDeleteModification == modificationType || kBXInsertModification == modificationType))
                            [mModifiedObjectIDs setObject: ModTypeToObject (kBXUpdateModification) forKey: currentID];
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
	
bail:
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
					BXEnumerate (currentID, e, [objectIDs objectEnumerator])
                        [[self registeredObjectWithID: currentID] setDeleted: kBXObjectDeletePending];
					
					//The change notice will only be delivered at commit time, but there could be e.g. two
					//BXSetHelperTableRelationProxies for one relationship, and objects get deleted from one of them.
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
                    BXEnumerate (currentID, e, [objectIDs objectEnumerator])
					{
						enum BXObjectDeletionStatus status = [[self registeredObjectWithID: currentID] deletionStatus];
						[[mUndoManager prepareWithInvocationTarget: currentID] setStatus: status forObjectRegisteredInContext: self];
					}
                    //Do the actual rollback.
					if (createdSavepoint)
						[[mUndoManager prepareWithInvocationTarget: self] rollbackToLastSavepoint];
					[[mUndoManager prepareWithInvocationTarget: self] undoWithRedoInvocations: [recorder recordedInvocations]];
                    //Remember the modification type for ROLLBACK.
					BXEnumerate (currentID, e, [objectIDs objectEnumerator])
					{
                        [[mUndoManager prepareWithInvocationTarget: mModifiedObjectIDs] setObject: [mModifiedObjectIDs objectForKey: currentID] 
                                                                                           forKey: currentID];                        
                        [mModifiedObjectIDs setObject: ModTypeToObject (kBXDeleteModification) forKey: currentID];
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
			title, NSLocalizedFailureReasonErrorKey, 
			reason, NSLocalizedRecoverySuggestionErrorKey, 
			self, kBXDatabaseContextKey,
			nil];
		
		if (NULL != error)
			*error = [BXError errorWithDomain: kBXErrorDomain code: kBXErrorNoDatabaseURI userInfo: userInfo];
	}
	return rval;
}

- (void) setDatabaseInterface: (id <BXInterface>) interface
{
	if (interface != mDatabaseInterface)
	{
		[mDatabaseInterface release];
		mDatabaseInterface  = [interface retain];
	}
}

- (id <BXInterface>) databaseInterface
{
	if (nil == mDatabaseInterface && mDatabaseURI)
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
		mObjects = PGTSDictionaryCreateMutableWeakNonretainedObjects ();
	}
	
	if (nil == mModifiedObjectIDs)
        mModifiedObjectIDs = [[NSMutableDictionary alloc] init];
	
	if (nil == mUndoGroupingLevels)
		mUndoGroupingLevels = [[NSMutableIndexSet alloc] init];
	
	if (YES == mUsesKeychain)
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

- (void) faultKeys: (NSArray *) keys inObjectsWithIDs: (NSArray *) ids
{
    BXEnumerate (currentObject, e, [[self registeredObjectsWithIDs: ids] objectEnumerator])
    {
        if ([NSNull null] != currentObject)
        {
            if (nil == keys)
                [currentObject faultKey: nil];
            else
            {
                BXEnumerate (currentKey, e, [keys objectEnumerator])
                    [currentObject faultKey: currentKey];
            }
        }
    }
}

- (void) setConnectionSetupManager: (id <BXConnector>) anObject
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
 * \brief Register an object to the context.
 *
 * After fetching objects from the database, a database interface should register them with a context.
 * This enables updating the database as well as automatic synchronization, if this has been implemented
 * in the database interface class.
 * \return A boolean. NO indicates that an object was already registered.
 */
- (BOOL) registerObject: (BXDatabaseObject *) anObject
{
    BOOL retval = NO;
    BXDatabaseObjectID* objectID = [anObject objectID];
    if (nil == [mObjects objectForKey: objectID])
    {
        retval = YES;
        [mObjects setObject: anObject forKey: objectID];
        if (mRetainRegisteredObjects)
            [anObject retain];
    }
    return retval;
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

- (void) setLastConnectionError: (NSError *) anError
{
	if (mLastConnectionError != anError)
	{
		[mLastConnectionError release];
		mLastConnectionError = [anError retain];
	}
}

- (void) setDatabaseObjectModel: (BXDatabaseObjectModel *) model
{
	if (model != mObjectModel)
	{
		[mObjectModel release];
		mObjectModel = [model retain];
	}
}

- (BXDatabaseObjectModel *) databaseObjectModel
{
	if (! mObjectModel && mDatabaseURI)
	{
		NSNumber* port = [mDatabaseURI port];
		if (! port)
			port = [mDatabaseInterface defaultPort];
		
		NSURL* key = [mDatabaseURI BXURIForHost: nil port: port database: nil username: @"" password: @""];
		[self setDatabaseObjectModel: [[BXDatabaseObjectModelStorage defaultStorage] objectModelForURI: key]];
	}
	return mObjectModel;
}

- (struct update_kvo_ctx) handleWillChangeForUpdate: (NSArray *) givenObjects newValues: (NSDictionary *) newValues
{
	NSMutableArray* changedObjects = [NSMutableArray array];
	NSMutableDictionary* relsByEntity = [NSMutableDictionary dictionary];
	NSMutableDictionary* oldTargetsByObject = [NSMutableDictionary dictionary];
	NSMutableDictionary* newTargetsByObject = [NSMutableDictionary dictionary];
	NSArray* objectIDs = (id) [[givenObjects PGTSCollect] objectID];
	NSMutableDictionary* idsByEntity = ObjectIDsByEntity (objectIDs);
	AddObjectIDsForInheritance (idsByEntity);
	
	BXEnumerate (entity, e, [idsByEntity keyEnumerator])
	{
		NSArray* objectIDs = [idsByEntity objectForKey: entity];
		NSArray* objects = [self registeredObjectsWithIDs: objectIDs nullObjects: NO];
		id rels = [entity inverseToOneRelationships];
		NSDictionary* oldTargets = nil;
		NSDictionary* newTargets = nil;
		
		[changedObjects addObjectsFromArray: objects];
		
		BXEnumerate (currentObject, e, [objects objectEnumerator])
		{
			BXEnumerate (currentAttr, e, [newValues keyEnumerator])
			[currentObject willChangeValueForKey: [currentAttr name]];
		}
		
		if (0 < [rels count])
		{
			[relsByEntity setObject: rels forKey: entity];
			BXEnumerate (currentObject, e, [objects objectEnumerator])
			{
				oldTargets = [[rels PGTSCollectDK] registeredTargetFor: currentObject fireFault: NO] ?: [NSDictionary dictionary];
				
				//FIXME: this seems really bad.
				NSDictionary* oldValues = [[[currentObject cachedValues] copy] autorelease];
				[currentObject setCachedValuesForKeysWithDictionary: newValues];
				
				newTargets = [[rels PGTSCollectDK] registeredTargetFor: currentObject fireFault: NO] ?: [NSDictionary dictionary];
				[currentObject setCachedValuesForKeysWithDictionary: oldValues];
				
				[currentObject willChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
				
				[oldTargetsByObject setObject: oldTargets forKey: currentObject];
				[newTargetsByObject setObject: newTargets forKey: currentObject];
			}
		}
	}
	
	struct update_kvo_ctx retval = {relsByEntity, changedObjects, oldTargetsByObject, newTargetsByObject};
	return retval;
}


- (void) handleDidChangeForUpdate: (struct update_kvo_ctx *) ctx newValues: (NSDictionary *) newValues sendNotifications: (BOOL) shouldSend targetEntity: (BXEntityDescription *) entity
{
	NSNotificationCenter* nc = [self notificationCenter];
	NSArray* changedObjects = ctx->ukc_objects;
	NSDictionary* relsByEntity = ctx->ukc_rels_by_entity;
	NSDictionary* oldTargetsByObject = ctx->ukc_old_targets_by_object;
	NSDictionary* newTargetsByObject = ctx->ukc_new_targets_by_object;
	
	BXEnumerate (currentObject, e, [changedObjects objectEnumerator])
	[currentObject setCachedValuesForKeysWithDictionary: newValues];
	
	NSArray* objectIDs = nil;
	NSDictionary* userInfo = nil;
	if (shouldSend)
	{
		objectIDs = (id) [[changedObjects PGTSCollect] objectID];
		userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
					objectIDs, kBXObjectIDsKey,
					changedObjects, kBXObjectsKey,
					self, kBXDatabaseContextKey,
					nil];
	}
	
	BXEnumerate (currentObject, e, [changedObjects objectEnumerator])
	{
		BXEnumerate (currentAttr, e, [newValues keyEnumerator])
		[currentObject didChangeValueForKey: [currentAttr name]];
	}
	
	BXEnumerate (currentObject, e, [changedObjects objectEnumerator])
	{
		NSDictionary* oldTargets = [oldTargetsByObject objectForKey: currentObject];
		NSDictionary* newTargets = [newTargetsByObject objectForKey: currentObject];
		id rels = [relsByEntity objectForKey: [currentObject entity]];
		if (0 < [rels count])
			[currentObject didChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
	}
	
	if (shouldSend)
		[nc postNotificationName: kBXUpdateEarlyNotification object: entity userInfo: userInfo];
}
@end


//FIXME: move these elsewhere.
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
    NSMutableArray* retval = nil;
    
    NSMutableData* attributeBuffer = (id) CFRetain ([NSMutableData data]);
    AddKeychainAttributeString (kSecAccountItemAttr, [mDatabaseURI user], attributeBuffer);
    AddKeychainAttributeString (kSecServerItemAttr,  [mDatabaseURI host], attributeBuffer);
    AddKeychainAttributeString (kSecPathItemAttr,    [mDatabaseURI path], attributeBuffer);

    SecAuthenticationType authType = kSecAuthenticationTypeDefault;
    AddKeychainAttribute (kSecAuthenticationTypeItemAttr, &authType, 
                          sizeof (SecAuthenticationType), attributeBuffer);

    //FIXME: For some reason we can't look for only non-invalid items
#if 0
    Boolean allowNegative = false;
    AddKeychainAttribute (kSecNegativeItemAttr, &allowNegative, sizeof (Boolean), attributeBuffer);
#endif
    
    NSNumber* portObject = [mDatabaseURI port];
    UInt16 port = (portObject ? [portObject unsignedShortValue] : 5432U);
    AddKeychainAttribute (kSecPortItemAttr, &port, sizeof (UInt16), attributeBuffer);
    
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
        retval = [NSMutableArray array];
        SecKeychainItemRef item = NULL;
        while (noErr == SecKeychainSearchCopyNext (search, &item))
            [retval addObject: (id) item];
        CFRelease (search);
    }
	
	//For GC.
	CFRelease (attributeBuffer);
	
    return retval;
}

- (SecKeychainItemRef) newestKeychainItem
{
    SecKeychainItemRef rval = NULL;
    UInt32 rvalModDate = 0;
    SecItemAttr attributes [] = {kSecModDateItemAttr, kSecNegativeItemAttr};
    SecExternalFormat formats [] = {kSecFormatUnknown, kSecFormatUnknown};
    unsigned int count = BXArraySize (attributes);
	BXAssertValueReturn (count == BXArraySize (formats), NULL,
						   @"Expected arrays to have an equal number of items.");
    SecKeychainAttributeInfo info = {count, (void *) attributes, (void *) formats};
    
    BXEnumerate (currentItem, e, [[self keychainItems] objectEnumerator])
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
        unsigned int count = BXArraySize (attributes);
        BXAssertValueReturn (count == BXArraySize (formats), NO,
							 @"Expected arrays to have an equal number of items.");
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
- (void) connectionSetupManagerFinishedAttempt
{
	if (NO == [self isConnected])
		[self setCanConnect: YES];
	[self setConnectionSetupManager: nil];
	[self setKeychainPasswordItem: NULL];
}
@end
