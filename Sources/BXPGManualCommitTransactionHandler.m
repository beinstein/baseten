//
// BXPGManualCommitTransactionHandler.m
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

#import "BXPGManualCommitTransactionHandler.h"
#import "BXPGManualCommitConnectionResetRecoveryAttempter.h"
#import "BXPGAdditions.h"
#import "BXProbes.h"


@implementation BXPGManualCommitTransactionHandler
- (PGTSDatabaseDescription *) databaseDescription
{
	return [mNotifyConnection databaseDescription];
}

- (PGTSConnection *) notifyConnection
{
	return mNotifyConnection;
}

- (void) dealloc
{
	[mNotifyConnection release];
	[super dealloc];
}
@end


@implementation BXPGManualCommitTransactionHandler (Observing)
- (BOOL) observeIfNeeded: (BXEntityDescription *) entity error: (NSError **) error
{
	return [self observeIfNeeded: entity connection: mNotifyConnection error: error];
}

- (void) checkSuperEntities: (BXEntityDescription *) entity
{
	[self checkSuperEntities: entity connection: mNotifyConnection];
}
@end


@implementation BXPGManualCommitTransactionHandler (Connecting)
- (BOOL) connected
{
	return (CONNECTION_OK == [mConnection connectionStatus] &&
			CONNECTION_OK == [mNotifyConnection connectionStatus]);
}

- (void) disconnect
{
	[mNotifyConnection executeQuery: @"SELECT baseten.ClearLocks ()"];
	[mNotifyConnection disconnect];
	[mConnection disconnect];
	[self didDisconnect];
}


- (void) prepareForConnecting
{
	mCounter = 2;
	
	[super prepareForConnecting];
	
	if (! mNotifyConnection)
	{
		mNotifyConnection = [[PGTSConnection alloc] init];
		[mNotifyConnection setDelegate: self];
		[mNotifyConnection setCertificateVerificationDelegate: mCertificateVerificationDelegate];
	}
}

- (void) connectAsync
{	
	[self prepareForConnecting];
	mAsync = YES;
	
	NSString* connectionString = [self connectionString];
	[mConnection connectAsync: connectionString];
	[mNotifyConnection connectAsync: connectionString];
}


- (BOOL) connectSync: (NSError **) outError
{
	ExpectR (outError, NO);
	
	[self prepareForConnecting];
	mAsync = NO;
	mSyncErrorPtr = outError;
	
	NSString* connectionString = [self connectionString];
	[mConnection connectSync: connectionString];
	[mNotifyConnection connectSync: connectionString];
	
	//-finishedConnecting gets executed here.
	
	mSyncErrorPtr = NULL;
	return mConnectionSucceeded;
}


- (void) finishedConnecting
{
	mCounter = 2; //For connection loss.
	
	//For simplicity, we only return one error. The error would probably be
	//the same for both connections anyway (e.g. invalid certificate, wrong password, etc.).
	PGTSConnection* failedConnection = nil;
	if (CONNECTION_BAD == [mConnection connectionStatus])
		failedConnection = mConnection;
	else if (CONNECTION_BAD == [mNotifyConnection connectionStatus])
		failedConnection = mNotifyConnection;
	
	if (failedConnection)
		[self handleConnectionErrorFor: failedConnection];
	else
	{
		[mNotifyConnection setDatabaseDescription: [mConnection databaseDescription]];
		[self handleSuccess];
	}
}


- (void) waitForConnection
{
	//Wait until both connections have finished.
	mCounter--;
	if (! mCounter)
		[self finishedConnecting];
}


- (void) handleSuccess
{
	[super handleSuccess];
	log4Debug (@"mNotifyConnection: %p", mNotifyConnection);
}


- (void) PGTSConnectionFailed: (PGTSConnection *) connection
{
	[self waitForConnection];
}


- (void) PGTSConnectionEstablished: (PGTSConnection *) connection
{
	[self waitForConnection];
}


- (void) PGTSConnectionLost: (PGTSConnection *) connection error: (NSError *) error
{
	if (! mHandlingConnectionLoss)
	{
		mHandlingConnectionLoss = YES;
		[self didDisconnect];

		//FIXME: determine somehow, whether the error is recoverable by connection reset or not.
		if (0 && [mConnection pgConnection] && [mNotifyConnection pgConnection])
		{
			Class attempterClass = [BXPGManualCommitConnectionResetRecoveryAttempter class];
			error = [self duplicateError: error recoveryAttempterClass: attempterClass];
		}
		[mInterface connectionLost: self error: error];
	}
}
@end



@implementation BXPGManualCommitTransactionHandler (Transactions)
- (BOOL) save: (NSError **) outError
{
	ExpectR(outError, NO);
	
	//COMMIT handles all transaction states.
	BOOL retval = YES;
	if (PQTRANS_IDLE != [mConnection transactionStatus])
	{
		retval = NO;
		
		PGTSResultSet* res = nil;
		NSError* localError = nil;
		res = [mNotifyConnection executeQuery: @"SELECT baseten.ClearLocks ()"];
		if ((localError = [res error])) *outError = localError;
		
		NSString* query = @"COMMIT";
		res = [mConnection executeQuery: query];
		if ((localError = [res error])) *outError = localError;
		
		if (BASETEN_SENT_COMMIT_TRANSACTION_ENABLED ())
		{
			char* message_s = strdup ([query UTF8String]);
			BASETEN_SENT_COMMIT_TRANSACTION (mConnection, [res status], message_s);
			free (message_s);
		}				
		
		if ([res querySucceeded])
			retval = YES;
	}
	[self resetSavepointIndex];	
	return retval;
}


- (void) rollback: (NSError **) outError
{
	ExpectV (outError);
	
    //The locked key should be cleared in any case to cope with the situation
    //where the lock was acquired after the last savepoint and the same key 
    //is to be locked again.
	//COMMIT handles all transaction states.
	if (PQTRANS_IDLE != [mConnection transactionStatus])
	{
		PGTSResultSet* res = nil;
		NSError* localError = nil;
		res = [mNotifyConnection executeQuery: @"SELECT baseten.ClearLocks ()"];
		if ((localError = [res error])) *outError = localError;
		
		NSString* query = @"ROLLBACK";
		res = [mConnection executeQuery: query];
		if ((localError = [res error])) *outError = localError;
		
		if (BASETEN_SENT_ROLLBACK_TRANSACTION_ENABLED ())
		{
			char* message_s = strdup ([query UTF8String]);
			BASETEN_SENT_ROLLBACK_TRANSACTION (mConnection, [res status], message_s);
			free (message_s);
		}		
	}
	[self resetSavepointIndex];	
}


- (BOOL) savepointIfNeeded: (NSError **) outError
{
	ExpectR (outError, NO);
	
	BOOL retval = NO;
	if ((retval = [self beginIfNeeded: outError]))
	{
		PGTransactionStatusType status = [mConnection transactionStatus];
		if (PQTRANS_INTRANS == status)
		{
			NSString* query = [self savepointQuery];
			PGTSResultSet* res = [mConnection executeQuery: query];
			
			if (BASETEN_SENT_SAVEPOINT_ENABLED ())
			{
				char* message_s = strdup ([query UTF8String]);
				BASETEN_SENT_SAVEPOINT (mConnection, [res status], message_s);
				free (message_s);
			}
			
			if ([res querySucceeded])
				retval = YES;
			else
				*outError = [res error];
		}
		else
		{
			//FIXME: handle the error.
		}
	}
	return retval;
}


- (BOOL) rollbackToLastSavepoint: (NSError **) outError
{
	ExpectR (outError, NO);
	
	BOOL retval = NO;
	PGTransactionStatusType status = [mConnection transactionStatus];
	if (PQTRANS_IDLE != status)
	{
		NSString* query = [self rollbackToSavepointQuery];
		PGTSResultSet* res = [mConnection executeQuery: query];
		
		if (BASETEN_SENT_ROLLBACK_TO_SAVEPOINT_ENABLED ())
		{
			char* message_s = strdup ([query UTF8String]);
			BASETEN_SENT_ROLLBACK_TO_SAVEPOINT (mConnection, [res status], message_s);
			free (message_s);			
		}
		
		if ([res querySucceeded])
			retval = YES;
		else
			*outError = [res error];
	}
	else 
	{
		//FIXME: set the error.
	}
	return retval;
}


- (BOOL) beginSubTransactionIfNeeded: (NSError **) outError
{
	return [self savepointIfNeeded: outError];
}


- (BOOL) endSubtransactionIfNeeded: (NSError **) outError
{
	return YES;
}


- (BOOL) autocommits
{
	return NO;
}
@end
