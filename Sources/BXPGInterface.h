//
// BXPGInterface.h
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
#import <BaseTen/BXInterface.h>
#import <BaseTen/BXEntityDescription.h>
#import <BaseTen/BXPropertyDescription.h>
#import <BaseTen/BXDatabaseObject.h>

@protocol BXObjectAsynchronousLocking;
@protocol BXRelationshipDescription;
@protocol PGTSConnectionDelegate;
@protocol PGTSResultRowProtocol;
@class PGTSConnection;
@class PGTSModificationNotifier;
@class PGTSLockNotifier;
@class PGTSTableInfo;
@class PGTSResultSet;
@class BXDatabaseContext;
@class BXDatabaseObjectID;

enum BXPGQueryState
{
    kBXPGQueryIdle = 0,
    kBXPGQueryBegun,
    kBXPGQueryLock,
};


@interface NSString (BXPGInterfaceAdditions)
- (NSArray *) BXPGKeyPathComponents;
@end


@interface BXEntityDescription (BXPGInterfaceAdditions)
- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection;
@end


@interface BXPropertyDescription (BXPGInterfaceAdditions)
- (id) PGTSConstantExpressionValue: (NSMutableDictionary *) context;
- (NSString *) BXPGEscapedName: (PGTSConnection *) connection;
@end


@interface BXDatabaseObject (BXPGInterfaceAdditions) <PGTSResultRowProtocol>
@end


@interface BXPGInterface : NSObject <BXInterface, PGTSConnectionDelegate> 
{
    BXDatabaseContext* context; //Weak
    NSURL* databaseURI;
    PGTSConnection* connection;
    PGTSConnection* notifyConnection;
    PGTSModificationNotifier* modificationNotifier;
    PGTSLockNotifier*  lockNotifier;
    BOOL autocommits;
    BOOL logsQueries;
    BOOL clearedLocks;
    
    enum BXPGQueryState state; /** What kind of query has been sent recently? */
    id <BXObjectAsynchronousLocking> locker;
    NSString* lockedKey;
    BXDatabaseObjectID* lockedObjectID;
}
@end


@interface BXPGInterface (Helpers)
- (BOOL) observeIfNeeded: (BXEntityDescription *) entity;
- (NSArray *) lockRowsWithObjectID: (BXDatabaseObjectID *) objectID 
                            entity: (BXEntityDescription *) entity
                       whereClause: (NSString *) whereClause
                        parameters: (NSArray *) parameters;
- (NSArray *) lockRowsWithObjectID: (BXDatabaseObjectID *) objectID 
                            entity: (BXEntityDescription *) entity
               pkeyTranslationDict: (NSDictionary *) translationDict
                       whereClause: (NSString *) whereClause
                        parameters: (NSArray *) parameters;
- (void) lockAndNotifyForEntity: (BXEntityDescription *) entity 
                    whereClause: (NSString *) whereClause
                     parameters: (NSArray *) parameters
                     willDelete: (BOOL) willDelete;
- (void) internalCommit;
- (void) internalRollback;
- (void) internalBegin;
- (NSString *) internalBeginQuery;
- (void) internalCommitNoSavepoint: (BOOL) noSavepoint;
- (void) internalRollbackNoSavepoint: (BOOL) noSavepoint;

- (void) packError: (NSError **) error exception: (NSException *) exception;
- (void) packPGError: (NSError **) error exception: (PGTSException *) exception;

- (NSDictionary *) lastModificationForEntity: (BXEntityDescription *) entity;
- (NSArray *) notificationObjectIDs: (NSNotification *) notification relidKey: (NSString *) relidKey;
- (NSArray *) notificationObjectIDs: (NSNotification *) notification relidKey: (NSString *) relidKey
                             status: (enum BXObjectStatus *) status;
@end


@interface BXPGInterface (Accessors)
- (void) setLocker: (id <BXObjectAsynchronousLocking>) anObject;
- (void) setLockedKey: (NSString *) aKey;
- (void) setLockedObjectID: (BXDatabaseObjectID *) lockedObjectID;
@end
