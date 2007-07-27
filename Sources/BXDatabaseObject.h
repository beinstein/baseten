//
// BXDatabaseObject.h
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

#import <Foundation/Foundation.h>

@class BXDatabaseContext;
@class BXDatabaseObject;
@class BXDatabaseObjectID;
@class BXEntityDescription;
@class BXRelationshipDescription;
@class BXAttributeDescription;


enum BXObjectDeletionStatus
{
	kBXObjectExists = 0,
	kBXObjectDeletePending,
	kBXObjectDeleted
};

enum BXObjectLockStatus
{
	kBXObjectNoLockStatus = 0,
	kBXObjectLockedStatus,
	kBXObjectDeletedStatus
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


@interface BXDatabaseObject : NSObject <NSCopying>
{
    BXDatabaseContext*			mContext; //Weak
    BXDatabaseObjectID*			mObjectID;
    NSMutableDictionary*		mValues;
	enum BXObjectDeletionStatus	mDeleted;
	enum BXObjectLockStatus		mLocked;
	BOOL						mCreatedInCurrentTransaction;
	BOOL						mNeedsToAwake;
}

- (BXEntityDescription *) entity;
- (BXDatabaseObjectID *) objectID;
- (BXDatabaseContext *) databaseContext;

- (id) objectForKey: (BXAttributeDescription *) aKey;
- (NSArray *) valuesForKeys: (NSArray *) keys;
- (NSArray *) objectsForKeys: (NSArray *) keys;
- (NSDictionary *) cachedObjects;

- (id <BXObjectStatusInfo>) statusInfo;
- (BOOL) isDeleted;
- (BOOL) isInserted;

- (id) primitiveValueForKey: (NSString *) aKey;
- (void) setPrimitiveValue: (id) aVal forKey: (NSString *) aKey;
- (void) setPrimitiveValuesForKeysWithDictionary: (NSDictionary *) aDict;

- (NSDictionary *) cachedValues;
- (id) cachedValueForKey: (NSString *) aKey;

- (BOOL) isLockedForKey: (NSString *) aKey;

- (void) faultKey: (NSString *) aKey;
- (int) isFaultKey: (NSString *) aKey;

- (BOOL) validateValue: (id *) ioValue forKey: (NSString *) key error: (NSError **) outError;
- (BOOL) validateForDelete: (NSError **) outError;
@end


@interface BXDatabaseObject (Subclassing)
- (id) init;
- (void) dealloc;

- (void) awakeFromFetch;
- (void) awakeFromInsert;
- (void) didTurnIntoFault;
@end
