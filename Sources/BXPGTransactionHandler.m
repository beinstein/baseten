//
// BXPGTransactionHandler.m
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

#import <PGTS/PGTSAdditions.h>
#import <PGTS/PGTSFunctions.h>

#import "BXDatabaseAdditions.h"
#import "BXInterface.h"
#import "BXProbes.h"
#import "BXLogger.h"

#import "BXPGTransactionHandler.h"
#import "BXPGAdditions.h"
#import "BXPGConnectionResetRecoveryAttempter.h"
#import "BXPGModificationHandler.h"
#import "BXPGLockHandler.h"
#import "BXPGClearLocksHandler.h"

#import "BXEntityDescriptionPrivate.h"


static NSString* 
SSLMode (enum BXSSLMode mode)
{
	NSString* retval = @"require";
	switch (mode) 
	{
		case kBXSSLModeDisable:
			retval = @"disable";
			break;
			
		case kBXSSLModePrefer:
		default:
			break;
	}
	return retval;
}


@implementation BXPGTransactionHandler
- (void) dealloc
{
	[mCertificateVerificationDelegate release];
	[mConnection release];
	[mObservedEntities release];
	[mObservers release];
	[mChangeHandlers release];
	[super dealloc];
}

- (PGTSConnection *) connection
{
	return mConnection;
}

- (void) setInterface: (BXPGInterface *) interface
{
	mInterface = interface;
}

- (BXPGInterface *) interface
{
	return mInterface;
}

- (BOOL) connected
{
	return (CONNECTION_OK == [mConnection connectionStatus]);
}

- (PGTSDatabaseDescription *) databaseDescription
{
	return [mConnection databaseDescription];
}

- (BOOL) isAsync
{
	return mAsync;
}

#pragma mark Connecting

- (void) didDisconnect
{
	[mObservedEntities removeAllObjects];
	[mObservers removeAllObjects];
	[mChangeHandlers removeAllObjects];
}

- (NSString *) connectionString
{
	BXDatabaseContext* ctx = [mInterface databaseContext];
	NSURL* databaseURI = [ctx databaseURI];
	NSMutableDictionary* connectionDict = [databaseURI BXPGConnectionDictionary];

	enum BXSSLMode sslMode = [ctx sslMode];
	[connectionDict setValue: SSLMode (sslMode) forKey: kPGTSSSLModeKey];
	
	return [connectionDict PGTSConnectionString];
}


- (void) prepareForConnecting
{
	mSyncErrorPtr = NULL;
	
	if (! mCertificateVerificationDelegate)
	{
		mCertificateVerificationDelegate = [[BXPGCertificateVerificationDelegate alloc] init];
		[mCertificateVerificationDelegate setHandler: self];
	}	
	
	if (! mConnection)
	{
		mConnection = [[PGTSConnection alloc] init];
		[mConnection setDelegate: self];
		[mConnection setCertificateVerificationDelegate: mCertificateVerificationDelegate];
	}	
}


- (void) handleConnectionErrorFor: (PGTSConnection *) failedConnection
{
	ExpectV (mAsync || mSyncErrorPtr);
	
	NSString* errorMessage = [failedConnection errorString];
	NSString* errorDescription = BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet");
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  errorMessage, NSLocalizedFailureReasonErrorKey,
							  errorMessage, NSLocalizedRecoverySuggestionErrorKey,
							  errorMessage, kBXErrorMessageKey,
							  errorDescription, NSLocalizedDescriptionKey,
							  nil];
	NSError* error = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorConnectionFailed userInfo: userInfo];

	if (mAsync)
		[mInterface connectionFailed: error];
	else
		*mSyncErrorPtr = error;
}


- (NSError *) connectionError: (NSError *) error recoveryAttempterClass: (Class) aClass
{
	//FIXME: move (parts of) this to the context.
	
	BXPGConnectionRecoveryAttempter* attempter = [[[aClass alloc] init] autorelease];
	attempter->mHandler = self;
	
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject: attempter forKey: NSRecoveryAttempterErrorKey];
	[userInfo setObject: @"Database Error" forKey: NSLocalizedDescriptionKey]; //FIXME: localization.
	[userInfo setObject: @"Connection to the database was lost." forKey: NSLocalizedFailureReasonErrorKey];
	[userInfo setObject: @"Connection to the database was lost." forKey: NSLocalizedRecoverySuggestionErrorKey];
	if (error) [userInfo setObject: error forKey: NSUnderlyingErrorKey];
	
	NSArray* options = [NSArray arrayWithObjects: @"Try to Reconnect", @"Continue", nil]; //FIXME: localization.
	[userInfo setObject: options forKey: NSLocalizedRecoveryOptionsErrorKey];
	
	return [NSError errorWithDomain: kBXErrorDomain code: kBXErrorConnectionLost userInfo: userInfo];
}


- (void) handleSuccess
{
	mConnectionSucceeded = YES;
	if (mAsync)
		[mInterface connectionSucceeded];
	BXLogDebug (@"mConnection: %p", mConnection);
}	


- (BOOL) connectSync: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (void) connectAsync
{
	[self doesNotRecognizeSelector: _cmd];
}


- (void) disconnect
{
	[self doesNotRecognizeSelector: _cmd];
}


#pragma mark TransactionHelpers

- (NSString *) savepointQuery
{
    mSavepointIndex++;
    return [NSString stringWithFormat: @"SAVEPOINT BXPGSavepoint%u", mSavepointIndex];
}

- (NSString *) rollbackToSavepointQuery
{
	mSavepointIndex--;
    return [NSString stringWithFormat: @"ROLLBACK TO SAVEPOINT BXPGSavepoint%u", mSavepointIndex];
}

- (void) resetSavepointIndex
{
	mSavepointIndex = 0;
}

- (NSUInteger) savepointIndex
{
	return mSavepointIndex;
}


#pragma mark Transactions

- (BOOL) beginIfNeeded: (NSError **) outError
{
	ExpectR (outError, NO);
	
	BOOL retval = NO;
	PGTransactionStatusType status = [mConnection transactionStatus];
	switch (status) 
	{
		case PQTRANS_INTRANS:
			retval = YES;
			break;
			
		case PQTRANS_IDLE:
		{
			NSString* query = @"BEGIN";
			PGTSResultSet* res = [mConnection executeQuery: query];
			
			if (BASETEN_SENT_BEGIN_TRANSACTION_ENABLED ())
			{
				char* message_s = strdup ([query UTF8String]);
				BASETEN_SENT_BEGIN_TRANSACTION (mConnection, [res status], message_s);
				free (message_s);
			}			
			
			if ([res querySucceeded])
				retval = YES;
			else
				*outError = [res error];
			
			break;
		}
			
		default:
			//FIXME: set an error.
			break;
	}
	return retval;
}


- (BOOL) save: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (void) rollback: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
}


- (BOOL) savepointIfNeeded: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) rollbackToLastSavepoint: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) beginSubTransactionIfNeeded: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) endSubtransactionIfNeeded: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) autocommits
{
	return NO;
}


#pragma mark Observing


- (BOOL) observeIfNeeded: (BXEntityDescription *) entity error: (NSError **) error
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) observeIfNeeded: (BXEntityDescription *) entity connection: (PGTSConnection *) connection error: (NSError **) error
{
	ExpectR (error, NO);
	ExpectR (entity, NO);
	
	BOOL retval = NO;
	
	if ([mObservedEntities containsObject: entity])
		retval = YES;
	else
	{
		if (! mObservedEntities)
			mObservedEntities = [[NSMutableSet alloc] init];
		if (! mObservers)
			mObservers = [[NSMutableDictionary alloc] init];
		if (! mChangeHandlers)
			mChangeHandlers = [[NSMutableDictionary alloc] init];
		
		PGTSDatabaseDescription* database = [connection databaseDescription];
		PGTSTableDescription* table = [mInterface tableForEntity: entity inDatabase: database error: error];
		if (table && [self addClearLocksHandler: connection error: error])
		{
			//Start listening to notifications and get the notification names.
			id oid = PGTSOidAsObject ([table oid]);
			NSString* query = 
			@"SELECT CURRENT_TIMESTAMP::TIMESTAMP WITHOUT TIME ZONE AS ts, null AS nname UNION ALL "
			@"SELECT null AS ts, baseten.ObserveModifications ($1) AS nname UNION ALL "
			@"SELECT null AS ts, baseten.ObserveLocks ($1) AS nname";
			PGTSResultSet* res = [connection executeQuery: query parameters: oid];
			if ([res querySucceeded] && 3 == [res count])
			{
				[res advanceRow];
				NSDate* lastCheck = [res valueForKey: @"ts"];
				
				Class observerClasses [] = {[BXPGModificationHandler class], [BXPGLockHandler class], Nil};
				Class aClass = Nil;
				int i = 0;
				while ((aClass = observerClasses [i]))
				{
					[res advanceRow];
					NSString* nname = [res valueForKey: @"nname"];
					
					//Create the observer.
					BXPGTableNotificationHandler* handler = [[aClass alloc] init];
					
					[handler setInterface: mInterface];
					[handler setConnection: connection];
					[handler setLastCheck: lastCheck];
					[handler setEntity: entity];
					[handler setTableName: nname];
					[handler prepare];
					
					[mObservers setObject: handler forKey: nname];
					if (0 == i)
						[mChangeHandlers setObject: handler forKey: entity];
					[handler release];
					
					i++;
				}
				
				[mObservedEntities addObject: entity];			
				retval = YES;
			}
			else
			{
				*error = [res error];
			}
		}
	}
	
	//Inheritance.
	TSEnumerate (currentEntity, e, [[entity inheritedEntities] objectEnumerator])
	{
		if (! retval)
			break;
		retval = [self observeIfNeeded: currentEntity connection: connection error: error];
	}
	
    return retval;
}


- (BOOL) addClearLocksHandler: (PGTSConnection *) connection 
						error: (NSError **) outError
{
	ExpectR (outError, NO);
	
	BOOL retval = NO;
	NSString* nname = [BXPGClearLocksHandler notificationName];
	if ([mObservers objectForKey: nname])
		retval = YES;
	else
	{
		NSString* query = [NSString stringWithFormat: @"LISTEN %@", [nname BXPGEscapedName: connection]];
		PGTSResultSet* res = [connection executeQuery: query];
		if ([res querySucceeded])
		{
			BXPGClearLocksHandler* handler = [[BXPGClearLocksHandler alloc] init];
			[handler setInterface: mInterface];
			[handler setConnection: connection];
			[handler prepare];
			[mObservers setObject: handler forKey: nname];
			[handler release];
			
			retval = YES;
		}
		else
		{
			*outError = [res error];
		}
	}
	return retval;
}


- (void) checkSuperEntities: (BXEntityDescription *) entity connection: (PGTSConnection *) connection
{
	TSEnumerate (superEntity, e, [[entity inheritedEntities] objectEnumerator])
		[[mChangeHandlers objectForKey: superEntity] checkModifications: 0];
}


- (void) checkSuperEntities: (BXEntityDescription *) entity
{
	[self doesNotRecognizeSelector: _cmd];
}


- (NSArray *) observedOids
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [mObservedEntities count]];
	TSEnumerate (currentEntity, e, [mObservedEntities objectEnumerator])
	{
		NSString* name = [currentEntity name];
		NSString* schemaName = [currentEntity schemaName];
		PGTSTableDescription* table = [[mConnection databaseDescription] table: name inSchema: schemaName];
		[retval addObject: PGTSOidAsObject ([table oid])];
	}
	return retval;
}
@end


@implementation BXPGTransactionHandler (PGTSConnectionDelegate)
- (void) PGTSConnection: (PGTSConnection *) connection receivedNotice: (NSError *) notice
{
	//BXLogDebug (@"%p: %s", connection, message);
	if (BASETEN_RECEIVED_PG_NOTICE_ENABLED ())
	{
		NSString* message = [[notice userInfo] objectForKey: kPGTSErrorMessage];
		char* message_s = strdup ([message UTF8String]);
		BASETEN_RECEIVED_PG_NOTICE (connection, message_s);
		free (message_s);
	}
}

- (void) PGTSConnection: (PGTSConnection *) connection gotNotification: (PGTSNotification *) notification
{
	NSString* notificationName = [notification notificationName];
	BXLogDebug (@"Got notification (%p): %@", self, connection, notificationName);
	[[mObservers objectForKey: notificationName] handleNotification: notification];
}


- (void) PGTSConnectionLost: (PGTSConnection *) connection error: (NSError *) error
{
	[self doesNotRecognizeSelector: _cmd];
}


- (void) PGTSConnectionFailed: (PGTSConnection *) connection
{
	[self doesNotRecognizeSelector: _cmd];
}


- (void) PGTSConnectionEstablished: (PGTSConnection *) connection
{
	[self doesNotRecognizeSelector: _cmd];
}
@end


@implementation BXPGTransactionHandler (BXPGTrustHandler)
- (BOOL) handleInvalidTrust: (SecTrustRef) trust result: (SecTrustResultType) result
{
	BOOL retval = NO;
	BXDatabaseContext* ctx = [mInterface databaseContext];
	if (mAsync)
	{
		CFRetain (trust);
		struct BXTrustResult trustResult = {trust, result};
		NSValue* resultValue = [NSValue valueWithBytes: &trustResult objCType: @encode (struct BXTrustResult)];				
		[ctx performSelectorOnMainThread: @selector (handleInvalidCopiedTrustAsync:) withObject: resultValue waitUntilDone: NO];
	}
	else
	{
		retval = [ctx handleInvalidTrust: trust result: result];
	}
	return retval;
}


- (void) handledTrust: (SecTrustRef) trust accepted: (BOOL) accepted
{
	if (! accepted)
	{
		[mCertificateVerificationDelegate setCertificates: nil];
	}
}
@end
