//
// BXDatabaseContextPrivate.h
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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


struct trustResult
{
	SecTrustRef trust;
	SecTrustResultType result;
};


@interface BXDatabaseContext (PrivateMethods)
/* Moved from the context. */
- (BOOL) executeDeleteFromEntity: (BXEntityDescription *) anEntity withPredicate: (NSPredicate *) predicate 
                           error: (NSError **) error;
- (NSSet *) relationshipsForEntity: (BXEntityDescription *) anEntity error: (NSError **) error;

/* Especially these need some attention before moving to a public header. */
- (void) lockObject: (BXDatabaseObject *) object key: (id) key status: (enum BXObjectLockStatus) status
             sender: (id <BXObjectAsynchronousLocking>) sender;
- (void) unlockObject: (BXDatabaseObject *) anObject key: (id) aKey;

/* Really internal. */
+ (void) loadedAppKitFramework;
- (id) executeFetchForEntity: (BXEntityDescription *) entity 
               withPredicate: (NSPredicate *) predicate 
             returningFaults: (BOOL) returnFaults 
             excludingFields: (NSArray *) excludedFields 
               returnedClass: (Class) returnedClass 
                       error: (NSError **) error;
- (NSArray *) executeUpdateObject: (BXDatabaseObject *) anObject entity: (BXEntityDescription *) anEntity 
                        predicate: (NSPredicate *) predicate withDictionary: (NSDictionary *) aDict 
                            error: (NSError **) error;
- (NSArray *) executeDeleteObject: (BXDatabaseObject *) anObject 
                           entity: (BXEntityDescription *) entity
                        predicate: (NSPredicate *) predicate
                            error: (NSError **) error;
- (BOOL) checkDatabaseURI: (NSError **) error;
- (BOOL) checkURIScheme: (NSURL *) url error: (NSError **) error;
- (id <BXInterface>) databaseInterface;
- (void) lazyInit;
- (void) setDatabaseURIInternal: (NSURL *) uri;
- (void) BXDatabaseObjectWillDealloc: (BXDatabaseObject *) anObject;
- (BOOL) registerObject: (BXDatabaseObject *) anObject;
- (void) unregisterObject: (BXDatabaseObject *) anObject;
- (void) handleError: (NSError *) anError;
- (void) setConnectionSetupManager: (id <BXConnectionSetupManager>) anObject;
- (void) faultKeys: (NSArray *) keys inObjectsWithIDs: (NSArray *) ids;
- (NSArray *) keyPathComponents: (NSString *) keyPath;
- (void) setCanConnect: (BOOL) aBool;
- (BXEntityDescription *) entityForTable: (NSString *) tableName inSchema: (NSString *) schemaName 
                     validateImmediately: (BOOL) validateImmediately error: (NSError **) error;
- (void) validateEntity: (BXEntityDescription *) entity error: (NSError **) error;
- (void) iterateValidationQueue: (NSError **) error;
@end


@interface BXDatabaseContext (Undoing)
- (void) undoGroupWillClose: (NSNotification *) notification;
- (BOOL) prepareSavepointIfNeeded: (NSError **) error;
- (void) undoWithRedoInvocations: (NSArray *) invocations;
- (void) redoInvocations: (NSArray *) invocations;
- (void) rollbackToLastSavepoint;
//- (void) reregisterObjects: (NSArray *) objectIDs values: (NSDictionary *) pkeyValues;
- (void) undoUpdateObjects: (NSArray *) objectIDs 
					oldIDs: (NSArray *) oldIDs 
		  createdSavepoint: (BOOL) createdSavepoint 
			   updatedPkey: (BOOL) updatedPkey 
				   oldPkey: (NSDictionary *) oldPkey
		   redoInvocations: (NSArray *) redoInvocations;
@end


@interface BXDatabaseContext (Keychain)
- (NSArray *) keychainItems;
- (SecKeychainItemRef) newestKeychainItem;
- (BOOL) fetchPasswordFromKeychain;
- (void) clearKeychainPasswordItem;
- (void) setKeychainPasswordItem: (SecKeychainItemRef) anItem;
@end


@interface BXDatabaseContext (Callbacks)
- (void) BXConnectionSetupManagerFinishedAttempt;
@end
