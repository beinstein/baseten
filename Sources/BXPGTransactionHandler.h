//
// BXPGTransactionHandler.h
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
#import <BaseTen/BXConstants.h>
#import <BaseTen/PGTSConnection.h>
#import <BaseTen/BXPGCertificateVerificationDelegate.h>


@class PGTSConnection;
@class BXEntityDescription;
@class BXPGInterface;
@class BXPGDatabaseDescription;
@class BXPGCertificateVerificationDelegate;
@class BXPGQueryBuilder;


BX_EXPORT NSString* kBXPGUserInfoKey;
BX_EXPORT NSString* kBXPGDelegateKey;
BX_EXPORT NSString* kBXPGCallbackSelectorStringKey;


@protocol BXPGResultSetPlaceholder <NSObject>
- (BOOL) querySucceeded;
- (id) userInfo;
- (NSError *) error;
@end



@interface BXPGTransactionHandler : NSObject 
{
	BXPGInterface* mInterface; //Weak.
	BXPGCertificateVerificationDelegate* mCertificateVerificationDelegate;
	PGTSConnection* mConnection;
	
	NSMutableSet* mObservedEntities;
	NSMutableDictionary* mObservers;
	NSMutableDictionary* mChangeHandlers;
	NSMutableDictionary* mLockHandlers;
	
	NSUInteger mSavepointIndex;
	NSError** mSyncErrorPtr;
	BOOL mAsync;
	BOOL mConnectionSucceeded;
	
	BOOL mIsResetting;
}
- (PGTSConnection *) connection;
- (BXPGInterface *) interface;
- (void) setInterface: (BXPGInterface *) interface;
- (BOOL) isAsync;
- (BOOL) isSSLInUse;

- (void) connectAsync;
- (BOOL) connectSync: (NSError **) outError;
- (void) disconnect;
- (BOOL) connected;
- (BOOL) usedPassword;

- (BOOL) canSend: (NSError **) outError;

- (NSString *) savepointQuery;
- (NSString *) rollbackToSavepointQuery;
- (void) resetSavepointIndex;
- (NSUInteger) savepointIndex;

- (void) prepareForConnecting;
- (void) didDisconnect;
- (NSString *) connectionString;
- (NSError *) connectionError: (NSError *) error recoveryAttempterClass: (Class) aClass;
- (BXPGDatabaseDescription *) databaseDescription;
- (void) refreshDatabaseDescription;

- (void) handleConnectionErrorFor: (PGTSConnection *) failedConnection;
- (void) handleSuccess;

- (BOOL) observeIfNeeded: (BXEntityDescription *) entity error: (NSError **) error;
- (BOOL) observeIfNeeded: (BXEntityDescription *) entity connection: (PGTSConnection *) connection error: (NSError **) error;
- (BOOL) addClearLocksHandler: (PGTSConnection *) connection error: (NSError **) outError;

- (void) checkSuperEntities: (BXEntityDescription *) entity;
- (void) checkSuperEntities: (BXEntityDescription *) entity connection: (PGTSConnection *) connection;
- (NSArray *) observedOids;

- (BOOL) logsQueries;
- (void) setLogsQueries: (BOOL) shouldLog;

- (void) markLocked: (BXEntityDescription *) entity 
	  relationAlias: (NSString *) alias
		 fromClause: (NSString *) fromClause
		whereClause: (NSString *) whereClause 
		 parameters: (NSArray *) parameters
		 willDelete: (BOOL) willDelete;
- (void) markLocked: (BXEntityDescription *) entity
	  relationAlias: (NSString *) alias
		 fromClause: (NSString *) fromClause
		whereClause: (NSString *) whereClause 
		 parameters: (NSArray *) parameters
		 willDelete: (BOOL) willDelete
		 connection: (PGTSConnection *) connection 
   notifyConnection: (PGTSConnection *) notifyConnection;

- (void) sendPlaceholderResultTo: (id) receiver callback: (SEL) callback 
					   succeeded: (BOOL) didSucceed userInfo: (id) userInfo;
- (void) forwardResult: (id) result;

- (void) reloadDatabaseMetadata;

/**
 * \internal
 * \brief Begins a transaction.
 *
 * Begins a transactions unless there already is one.
 */
- (BOOL) beginIfNeeded: (NSError **) outError;
- (void) beginIfNeededFor: (id) delegate callback: (SEL) callback userInfo: (id) userInfo;

/**
 * \internal
 * \brief Commits the current transaction.
 */
- (BOOL) save: (NSError **) outError;

/**
 * \internal
 * \brief Cancels the current transaction.
 */
- (BOOL) rollback: (NSError **) outError;

/**
 * \internal
 * \brief Creates a savepoint if needed.
 *
 * Use with single queries.
 */
- (BOOL) savepointIfNeeded: (NSError **) outError;

/**
 * \internal
 * \brief Rollback to last savepoint.
 */
- (BOOL) rollbackToLastSavepoint: (NSError **) outError;

/**
 * \internal
 * \brief Creates a savepoint or begins a transaction.
 *
 * Use with multiple queries.
 */
- (BOOL) beginSubTransactionIfNeeded: (NSError **) outError;
- (void) beginAsyncSubTransactionFor: (id) delegate callback: (SEL) callback userInfo: (NSDictionary *) userInfo;

/**
 * \internal
 * \brief Commits a previously begun subtransaction.
 */
- (BOOL) endSubtransactionIfNeeded: (NSError **) outError;

/**
 * \internal
 * \brief Rollback a previously begun subtransaction.
 */
- (void) rollbackSubtransaction;

- (BOOL) autocommits;

@end


@interface BXPGTransactionHandler (PGTSConnectionDelegate) <PGTSConnectionDelegate>
@end


@interface BXPGTransactionHandler (BXPGTrustHandler) <BXPGTrustHandler>
@end
