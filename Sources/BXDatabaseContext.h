//
// BXDatabaseContext.h
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

#ifndef IBAction
#define IBAction void
#endif


@protocol BXInterface;
@protocol BXObjectAsynchronousLocking;
@protocol BXRelationshipDescription;
@class BXDatabaseObject;
@class BXEntityDescription;
@class BXDatabaseObjectID;
@class TSNonRetainedObjectDictionary;
@class TSNonRetainedObjectSet;


@interface BXDatabaseContext : NSObject
{
    id <BXInterface>             mDatabaseInterface;
    NSURL*                          mDatabaseURI;
    NSMutableSet*                   mSeenEntities;
    TSNonRetainedObjectDictionary*  mObjects;
    NSMutableSet*                   mModifiedObjectIDs;
    NSUndoManager*                  mUndoManager;
    BOOL                            mLogsQueries;
    BOOL                            mAutocommits;
    BOOL                            mDeallocating;
}
+ (BOOL) setInterfaceClass: (Class) aClass forScheme: (NSString *) scheme;
+ (Class) interfaceClassForScheme: (NSString *) scheme;

+ (id) contextWithDatabaseURI: (NSURL *) uri;
- (id) initWithDatabaseURI: (NSURL *) uri;
- (void) setDatabaseURI: (NSURL *) uri;
- (NSURL *) databaseURI;

- (BOOL) hasSeenEntity: (BXEntityDescription *) anEntity;
- (NSSet *) seenEntities;
- (void) setHasSeen: (BOOL) aBool entity: (BXEntityDescription *) anEntity;

- (void) setAutocommits: (BOOL) aBool;
- (BOOL) autocommits;

- (void) BXDatabaseObjectWillDealloc: (BXDatabaseObject *) anObject;

- (BOOL) logsQueries;
- (void) setLogsQueries: (BOOL) aBool;
- (void) connectIfNeeded: (NSError **) error;

- (BOOL) registerObject: (BXDatabaseObject *) anObject;
- (void) unregisterObject: (BXDatabaseObject *) anObject;
- (BXDatabaseObject *) registeredObjectWithID: (BXDatabaseObjectID *) objectID;
- (NSArray *) registeredObjectsWithIDs: (NSArray *) objectIDs;
- (NSArray *) registeredObjectsWithIDs: (NSArray *) objectIDs nullObjects: (BOOL) returnNullObjects;

- (NSUndoManager *) undoManager;
- (BOOL) setUndoManager: (NSUndoManager *) aManager;

- (void) undoWithRedoInvocations: (NSArray *) invocations;
- (void) redoInvocations: (NSArray *) invocations;

- (void) handleError: (NSError *) anError;
@end


@interface BXDatabaseContext (Queries)
- (void) rollback;
- (BOOL) save: (NSError **) error;

- (id) objectWithID: (BXDatabaseObjectID *) anID error: (NSError **) error;
- (NSSet *) objectsWithIDs: (NSArray *) anArray error: (NSError **) error;
- (NSArray *) faultsWithIDs: (NSArray *) anArray;

- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) 
                    predicate error: (NSError **) error;
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
                    returningFaults: (BOOL) returnFaults error: (NSError **) error;
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
                    excludingFields: (NSArray *) excludedFields error: (NSError **) error;
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
                    returningFaults: (BOOL) returnFaults updateAutomatically: (BOOL) shouldUpdate error: (NSError **) error;
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
                    excludingFields: (NSArray *) excludedFields updateAutomatically: (BOOL) shouldUpdate error: (NSError **) error;

- (id) createObjectForEntity: (BXEntityDescription *) entity withFieldValues: (NSDictionary *) fieldValues error: (NSError **) error;

- (BOOL) executeDeleteObject: (BXDatabaseObject *) anObject error: (NSError **) error;

- (BOOL) fireFault: (BXDatabaseObject *) anObject key: (id) aKey error: (NSError **) error;

@end


@interface BXDatabaseContext (DBInterfaces)
- (void) addedObjectsToDatabase: (NSArray *) objectIDs;
- (void) updatedObjectsInDatabase: (NSArray *) objectIDs;
- (void) deletedObjectsFromDatabase: (NSArray *) objectIDs;
- (void) lockedObjectsInDatabase: (NSArray *) objectIDs status: (enum BXObjectStatus) status;
- (void) unlockedObjectsInDatabase: (NSArray *) objectIDs;
@end


@interface BXDatabaseContext (HelperMethods)
- (void) faultKeys: (NSArray *) keys inObjectsWithIDs: (NSArray *) ids;
- (NSArray *) objectIDsForEntity: (BXEntityDescription *) anEntity error: (NSError **) error;
- (NSArray *) objectIDsForEntity: (BXEntityDescription *) anEntity predicate: (NSPredicate *) predicate error: (NSError **) error;
- (NSArray *) keyPathComponents: (NSString *) keyPath;
- (BXEntityDescription *) entityForTable: (NSString *) tableName inSchema: (NSString *) schemaName;
- (BXEntityDescription *) entityForTable: (NSString *) tableName;
- (NSDictionary *) relationshipsByNameWithEntity: (BXEntityDescription *) anEntity
                                          entity: (BXEntityDescription *) anotherEntity;
- (NSDictionary *) relationshipsByNameWithEntity: (BXEntityDescription *) anEntity
                                          entity: (BXEntityDescription *) anotherEntity
                                           types: (enum BXRelationshipType) bitmap;
@end


@interface BXDatabaseContext (NSCoding) <NSCoding> 
//Only basic support for Interface Builder
@end


@interface BXDatabaseContext (IBActions)
- (IBAction) saveDocument: (id) sender;
- (IBAction) revertDocumentToSaved: (id) sender;
@end

