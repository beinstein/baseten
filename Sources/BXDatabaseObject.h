//
// BXDatabaseObject.h
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

#import <Foundation/Foundation.h>

@class BXDatabaseContext;
@class BXDatabaseObject;
@class BXDatabaseObjectID;
@class BXEntityDescription;
@class BXRelationshipDescription;
@class BXPropertyDescription;


/** Object lock status */
enum BXObjectLockStatus
{
    kBXObjectNoLockStatus = 0,
    kBXObjectLockedStatus,
    kBXObjectDeletedStatus,
};

/** Object existence */
enum BXObjectStoreStatus
{
	kBXObjectNoStoreStatus = 0,
	kBXObjectInsertPending,	//After insert before commit
	kBXObjectDeletePending,	//After delete before commit
	kBXObjectDeleted		//After insert + rollback and delete + commit
};


@protocol BXObjectStatusInfo <NSObject>
- (BXDatabaseObjectID *) objectID;
- (NSNumber *) unlocked; //Returns a boolean
- (BOOL) isLockedForKey: (NSString *) aKey;
- (BOOL) isDeleted;
- (void) faultKey: (NSString *) aKey;
- (id) valueForKey: (NSString *) aKey;
- (void) addObserver: (NSObject *) anObserver forKeyPath: (NSString *) keyPath 
             options: (NSKeyValueObservingOptions) options context: (void *) context;
@end

/** 
 * \internal
 * A protocol for performing a callback during a status change. 
 */
@protocol BXObjectAsynchronousLocking <NSObject>
/**
 * Callback for acquiring a lock in the database.
 * \param   lockAcquired        A boolean indicating whether the operation was
 *                              successful or not
 * \param   receiver            The target object
 */
- (void) BXLockAcquired: (BOOL) lockAcquired object: (BXDatabaseObject *) receiver;
@end


@interface BXDatabaseObject : NSObject
{
    BXDatabaseContext*			mContext; //Weak
    BXDatabaseObjectID*			mObjectID;
    NSMutableDictionary*		mValues;
    enum BXObjectLockStatus     mLockStatus;
}

+ (BOOL) accessInstanceVariablesDirectly;
- (BXDatabaseObjectID *) objectID;
- (BXDatabaseContext *) databaseContext;
- (BOOL) registerWithContext: (BXDatabaseContext *) ctx entity: (BXEntityDescription *) entity;
- (BOOL) registerWithContext: (BXDatabaseContext *) ctx objectID: (BXDatabaseObjectID *) anID;
- (void) removePrimaryKeyValuesFromStore;

- (id) objectForKey: (BXPropertyDescription *) aKey;
- (NSArray *) valuesForKeys: (NSArray *) keys;
- (NSArray *) objectsForKeys: (NSArray *) keys;
- (id) valueForUndefinedKey: (NSString *) aKey;
- (void) setValue: (id) aValue forUndefinedKey: (NSString *) aKey;
- (NSDictionary *) cachedObjects;
- (void) lockKey: (id) key status: (enum BXObjectLockStatus) objectStatus sender: (id <BXObjectAsynchronousLocking>) sender;

//- (void) conditionallyFaultAllKeys;
//- (void) conditionallyFaultKey: (id) aKey;

- (void) BXDatabaseContextWillDealloc;

- (id <BXObjectStatusInfo>) statusInfo;
- (void) clearStatus;
- (BOOL) isDeleted;
- (void) setDeleted;

- (id) primitiveValueForKey: (NSString *) aKey;
- (void) setPrimitiveValue: (id) aVal forKey: (NSString *) aKey;
- (void) setPrimitiveValuesForKeysWithDictionary: (NSDictionary *) aDict;

- (NSDictionary *) cachedValues;
- (id) cachedValueForKey: (NSString *) aKey;
- (void) setCachedValue: (id) aValue forKey: (NSString *) aKey;
- (void) setCachedValuesForKeysWithDictionary: (NSDictionary *) aDict;

- (BOOL) isLockedForKey: (NSString *) aKey;
- (void) setLockedForKey: (NSString *) aKey;

- (void) faultKey: (NSString *) aKey;
- (int) isFaultKey: (NSString *) aKey;

- (BOOL) checkNullConstraintForValue: (id *) ioValue key: (NSString *) key error: (NSError **) outError;
@end


@interface BXDatabaseObject (Subclassing)
- (id) init;
- (void) dealloc;

- (void) awakeFromFetch;
- (void) awakeFromInsert;
@end
