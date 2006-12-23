//
// BXInterface.h
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

@protocol BXObjectAsynchronousLocking;
@protocol BXRelationshipDescription;
@class BXDatabaseContext;
@class BXDatabaseObject;
@class BXDatabaseObjectID;
@class BXEntityDescription;


/**
 * \internal
 * BXInterface.
 * Formal part of the protocol
 */
@protocol BXInterface <NSObject>

- (id) initWithContext: (BXDatabaseContext *) aContext databaseURI: (NSURL *) url;

/** \name Capabilities */
//@{
- (BOOL) messagesForViewModifications;
//@}

/** \name Queries */
//@{
- (id) createObjectForEntity: (BXEntityDescription *) entity withFieldValues: (NSDictionary *) fieldValues
                       class: (Class) aClass error: (NSError **) error;
- (NSMutableArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
                           returningFaults: (BOOL) returnFaults excludingFields: (NSArray *) excludedFields 
                                     class: (Class) aClass error: (NSError **) error;
- (BOOL) fireFault: (BXDatabaseObject *) anObject key: (id) aKey error: (NSError **) error;
- (NSArray *) executeUpdateWithDictionary: (NSDictionary *) aDict
                                 objectID: (BXDatabaseObjectID *) anID
                                   entity: (BXEntityDescription *) entity
                                predicate: (NSPredicate *) predicate
                                    error: (NSError **) error;
- (NSArray *) executeDeleteObjectWithID: (BXDatabaseObjectID *) objectID 
                                 entity: (BXEntityDescription *) entity 
                              predicate: (NSPredicate *) predicate 
                                  error: (NSError **) error;

/** 
 * Lock an object asynchronously.
 */
- (void) lockObject: (BXDatabaseObject *) object key: (id) key lockType: (enum BXObjectStatus) type
             sender: (id <BXObjectAsynchronousLocking>) sender;
/**
 * Unlock a locked object synchronously.
 */
- (void) unlockObject: (BXDatabaseObject *) anObject key: (id) aKey;
//@}

- (BOOL) connected;

/** \name Connecting to the database */
//@{
- (BOOL) connectIfNeeded: (NSError **) error;
//@}

- (NSArray *) keyPathComponents: (NSString *) keyPath;
- (void) setLogsQueries: (BOOL) aBool;
- (BOOL) logsQueries;

- (NSDictionary *) relationshipsByNameWithEntity: (BXEntityDescription *) srcEntity
                                          entity: (BXEntityDescription *) givenDSTEntity
                                           types: (enum BXRelationshipType) typeBitmap;

/** \name Transactions */
//@{
- (void) rollback;
- (BOOL) save: (NSError **) error;
- (void) setAutocommits: (BOOL) aBool;
- (BOOL) autocommits;
- (void) undo;
//@}

- (id) validateEntity: (BXEntityDescription *) entity;
@end
