//
// BXPGAutocommitTransactionHandler.m
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

#import "BXPGAutocommitTransactionHandler.h"
#import "BXPGAutocommitConnectionResetRecoveryAttempter.h"
#import "BXPGReconnectionRecoveryAttempter.h"
#import "BXPGAdditions.h"
#import "BXProbes.h"


@implementation BXPGAutocommitTransactionHandler
@end


@implementation BXPGAutocommitTransactionHandler (Observing)
- (BOOL) observeIfNeeded: (BXEntityDescription *) entity error: (NSError **) error
{
	return [self observeIfNeeded: entity connection: mConnection error: error];
}

- (void) checkSuperEntities: (BXEntityDescription *) entity
{
	[self checkSuperEntities: entity connection: mConnection];
}
@end


@implementation BXPGAutocommitTransactionHandler (Connecting)
- (void) disconnect
{
	[mConnection disconnect];
	[self didDisconnect];
}


- (void) connectAsync
{
	[self prepareForConnecting];
	mAsync = YES;
	
	NSString* connectionString = [self connectionString];
	[mConnection connectAsync: connectionString];
}


- (void) connectSync: (NSError **) outError
{
	ExpectV (outError);
	
	[self prepareForConnecting];
	mAsync = NO;
	mSyncErrorPtr = outError;
	
	NSString* connectionString = [self connectionString];
	[mConnection connectSync: connectionString];
	
	//-finishedConnecting gets executed here.
	
	mSyncErrorPtr = NULL;
}


- (void) PGTSConnectionFailed: (PGTSConnection *) connection
{
	[self handleConnectionErrorFor: connection];
}


- (void) PGTSConnectionEstablished: (PGTSConnection *) connection
{
	[self handleSuccess];
}


- (void) PGTSConnectionLost: (PGTSConnection *) connection error: (NSError *) error
{
	[self didDisconnect];
	
	Class attempterClass = Nil;
	if ([connection pgConnection])
		attempterClass = [BXPGAutocommitConnectionResetRecoveryAttempter class];
	else
		attempterClass = [BXPGReconnectionRecoveryAttempter class];

	error = [self connectionError: error recoveryAttempterClass: attempterClass];
	[mInterface connectionLost: self error: error];
}
@end


@implementation BXPGAutocommitTransactionHandler (Transactions)
- (BOOL) save: (NSError **) outError
{
	ExpectR (outError, NO);
	
	//COMMIT handles all transaction states.
	BOOL retval = YES;
	if (PQTRANS_IDLE != [mConnection transactionStatus])
	{
		retval = NO;
		
		NSString* query = @"COMMIT; SELECT baseten.ClearLocks ();";
		PGTSResultSet* res = [mConnection executeQuery: query];
		*outError = [res error];
		
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
    //where the lock was acquired  after the last savepoint and the same key 
    //is to be locked again.
	//ROLLBACK handles all transaction states.
	if (PQTRANS_IDLE != [mConnection transactionStatus])
	{
		NSString* query = @"ROLLBACK; SELECT baseten.ClearLocks ();";
		PGTSResultSet* res = [mConnection executeQuery: query];
		*outError = [res error];
		
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
	return YES;
}


- (BOOL) beginSubTransactionIfNeeded: (NSError **) outError
{
	return [self beginIfNeeded: outError];
}


- (BOOL) endSubtransactionIfNeeded: (NSError **) outError
{
	return [self save: outError];
}


- (BOOL) autocommits
{
	return YES;
}
@end
