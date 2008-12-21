//
// BXInterface.h
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

#import <Foundation/Foundation.h>
#import <BaseTen/BXDatabaseContext.h>
#import <Security/Security.h>

@protocol BXObjectAsynchronousLocking;
@class BXDatabaseContext;
@class BXDatabaseObject;
@class BXDatabaseObjectID;
@class BXEntityDescription;


struct BXTrustResult
{
	SecTrustRef trust;
	SecTrustResultType result;
};


@interface BXDatabaseContext (DBInterfaces)
- (BOOL) connectedToDatabase: (BOOL) connected async: (BOOL) async error: (NSError **) error;
- (void) connectionLost: (NSError *) error;
- (void) addedObjectsToDatabase: (NSArray *) objectIDs;
- (void) updatedObjectsInDatabase: (NSArray *) objectIDs faultObjects: (BOOL) shouldFault;
- (void) deletedObjectsFromDatabase: (NSArray *) objectIDs;
- (void) lockedObjectsInDatabase: (NSArray *) objectIDs status: (enum BXObjectLockStatus) status;
- (void) unlockedObjectsInDatabase: (NSArray *) objectIDs;
- (void) handleInvalidCopiedTrustAsync: (NSValue *) value;
- (BOOL) handleInvalidTrust: (SecTrustRef) trust result: (SecTrustResultType) result;
- (NSError *) packQueryError: (NSError *) error;
- (enum BXSSLMode) sslMode;
- (void) networkStatusChanged: (SCNetworkConnectionFlags) newFlags;
@end


/**
 * \internal
 * BXInterface.
 * Formal part of the protocol
 */
@protocol BXInterface <NSObject>

- (id) initWithContext: (BXDatabaseContext *) aContext;

- (BOOL) logsQueries;
- (void) setLogsQueries: (BOOL) shouldLog;

/** 
 * \internal
 * \name Queries 
 */
//@{
- (id) createObjectForEntity: (BXEntityDescription *) entity withFieldValues: (NSDictionary *) fieldValues
                       class: (Class) aClass error: (NSError **) error;
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
					returningFaults: (BOOL) returnFaults class: (Class) aClass error: (NSError **) error;
- (BOOL) fireFault: (BXDatabaseObject *) anObject keys: (NSArray *) keys error: (NSError **) error;
- (NSArray *) executeUpdateWithDictionary: (NSDictionary *) aDict
                                 objectID: (BXDatabaseObjectID *) anID
                                   entity: (BXEntityDescription *) entity
                                predicate: (NSPredicate *) predicate
                                    error: (NSError **) error;
- (NSArray *) executeDeleteObjectWithID: (BXDatabaseObjectID *) objectID 
                                 entity: (BXEntityDescription *) entity 
                              predicate: (NSPredicate *) predicate 
                                  error: (NSError **) error;
- (NSArray *) executeQuery: (NSString *) queryString parameters: (NSArray *) parameters error: (NSError **) error;
- (unsigned long long) executeCommand: (NSString *) commandString error: (NSError **) error;

/** 
 * \internal
 * Lock an object asynchronously.
 */
- (void) lockObject: (BXDatabaseObject *) object key: (id) key lockType: (enum BXObjectLockStatus) type
             sender: (id <BXObjectAsynchronousLocking>) sender;
/**
 * \internal
 * Unlock a locked object synchronously.
 */
- (void) unlockObject: (BXDatabaseObject *) anObject key: (id) aKey;
//@}

- (BOOL) connected;

/** 
 * \internal
 * \name Connecting to the database 
 */
//@{
- (BOOL) connectSync: (NSError **) error;
- (void) connectAsync;
- (void) disconnect;
//@}

#if 0
- (void) setLogsQueries: (BOOL) aBool;
- (BOOL) logsQueries;
#endif

- (NSDictionary *) entitiesBySchemaAndName: (NSError **) error;
- (NSDictionary *) relationshipsForEntity: (BXEntityDescription *) anEntity error: (NSError **) error;

/**
 * \internal
 * \name Transactions 
 */
//@{
- (void) rollback;
- (BOOL) save: (NSError **) error;

- (void) setAutocommits: (BOOL) aBool;
- (BOOL) autocommits;

- (BOOL) rollbackToLastSavepoint: (NSError **) error;
- (BOOL) establishSavepoint: (NSError **) error;
//@}

- (void) handledTrust: (SecTrustRef) trust accepted: (BOOL) accepted;
- (BOOL) validateEntity: (BXEntityDescription *) entity error: (NSError **) error;
- (BOOL) isSSLInUse;
@end
