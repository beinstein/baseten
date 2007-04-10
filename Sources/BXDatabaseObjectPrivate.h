//
// BXDatabaseObjectPrivate.h
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


@interface BXDatabaseObject (PrivateMethods)
- (BOOL) isCreatedInCurrentTransaction;
- (void) setCreatedInCurrentTransaction: (BOOL) aBool;
- (enum BXObjectDeletionStatus) deletionStatus;
- (void) setDeleted: (enum BXObjectDeletionStatus) status;
- (BOOL) checkNullConstraintForValue: (id *) ioValue key: (NSString *) key error: (NSError **) outError;
- (void) setCachedValue: (id) aValue forKey: (NSString *) aKey;
- (void) setCachedValuesForKeysWithDictionary: (NSDictionary *) aDict;
- (void) BXDatabaseContextWillDealloc;
- (id) valueForUndefinedKey: (NSString *) aKey;
- (void) setValue: (id) aValue forUndefinedKey: (NSString *) aKey;
- (void) lockKey: (id) key status: (enum BXObjectLockStatus) objectStatus sender: (id <BXObjectAsynchronousLocking>) sender;
- (void) lockForDelete;
- (void) clearStatus;
- (void) setLockedForKey: (NSString *) aKey;
- (BOOL) registerWithContext: (BXDatabaseContext *) ctx entity: (BXEntityDescription *) entity;
- (BOOL) registerWithContext: (BXDatabaseContext *) ctx objectID: (BXDatabaseObjectID *) anID;
- (void) removePrimaryKeyValuesFromStore;
- (BOOL) lockedForDelete;
- (void) awakeFromFetchIfNeeded;
- (NSArray *) keysIncludedInQuery: (id) aKey;
- (void) awakeFromInsertIfNeeded;
@end
