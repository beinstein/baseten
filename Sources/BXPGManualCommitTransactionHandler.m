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

#import "BXPGTransactionHandler.h"


@implementation BXPGManualCommitTransactionHandler (Connecting)
- (void) prepareForConnecting
{
	mCounter = 2;
	
	[super prepareForConnecting];
	
	if (! mNotifyConnection)
	{
		mNotifyConnection = [[PGTSConnection alloc] init];
		[mConnection setDelegate: self];
	}
}

- (void) connectAsync
{	
	[self prepareForConnecting];
	mSync = NO;
	
	NSString* connectionString = nil; //FIXME: get this somehow.
	[mConnection connectAsync: connectionString];
	[mNotifyConnection connectAsync: connectionString];
}


- (BOOL) connectSync: (NSError **) outError
{
	ExpectV (outError);
	
	[self prepareForConnecting];
	mSync = YES;
	mSyncErrorPtr = outError;
	
	NSString* connectionString = [self connectionString];
	[mConnection connectSync: connectionString];
	[mNotifyConnection connectSync: connectionString];
	
	//-finishedConnecting gets executed here.
	
	mSyncErrorPtr = NULL;
	return mConnectionSucceeded;
}


- (void) waitForConnection
{
	//Wait until both connections have finished.
	mCounter--;
	if (! mCounter)
		[self finishedConnecting];
}


- (void) PGTSConnectionFailed: (PGTSConnection *) connection
{
	[self waitForConnection];
}


- (void) PGTSConnectionEstablished: (PGTSConnection *) connection
{
	[self waitForConnection];
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
		[self handleSuccess];
}


- (void) PGTSConnectionLost: (PGTSConnection *) connection error: (NSError *) error
{
	//FIXME: determine somehow, whether the error is recoverable by connection reset or not.
	if (0 && [mConnection pgConnection] && [mNotifyConnection pgConnection])
	{
		Class attempterClass = [BXPGManualCommitConnectionResetRecoveryAttempter class];
		error = [self duplicateError: error recoveryAttempterClass: attempterClass];
	}
	[mInterface connectionLost: self error: error];
}
@end



@interface BXPGManualCommitTransactionHandler (Transactions)
- (void) rollback: (NSError **) outError
{
	ExpectV (outError);
	
    //The locked key should be cleared in any case to cope with the situation
    //where the lock was acquired after the last savepoint and the same key 
    //is to be locked again.
	if (PQTRANS_IDLE != [mConnection transactionStatus])
	{
		PGTSResultSet* res = nil;
		NSError* localError = nil;
		res = [mNotifyConnection executeQuery: @"SELECT baseten.ClearLocks ()"];
		if ((localError = [res error])) *outError = localError;
		res = [mConnection executeQuery: @"ROLLBACK"];
		if ((localError = [res error])) *outError = localError;
	}
	[self resetSavepointIndex];	
}
@end



@implementation BXPGManualCommitConnectionResetRecoveryAttempter
- (BOOL) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex
{
	if (0 == recoveryOptionIndex)
	{
		[mConnection resetSync];
		[mNotifyConnection resetSync];
		//-finishedConnecting gets executed here.
	}
	return mSucceeded;
}


- (void) finishedConnecting
{
	ConnStatusType s1 = [mConnection connectionStatus];
	ConnStatusType s2 = [mNotifyConnection connectionStatus];
	mSucceeded = (CONNECTION_OK == s1 && CONNECTION_OK == s2);
	
	if (! mSucceeded)
	{
		[mConnection disconnect];
		[mNotifyConnection disconnect];
	}
	else
	{
		[mConnection setDelegate: mHandler];
		[mNotifyConnection setDelegate: mHandler];
	}
	
	if (mIsAsync)
	{
		[mRecoveryInvocation setArgument: &mSucceeded atIndex: 2];
		[mRecoveryInvocation invoke];
		//FIXME: check modification tables?
	}
}


- (void) waitForConnection
{
	//Wait until both connections have finished.
	mCounter--;
	if (! mCounter)
		[self finishedConnecting];
}


- (void) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex 
						 delegate: (id) delegate didRecoverSelector: (SEL) didRecoverSelector contextInfo: (void *) contextInfo
{
	mCounter = 2;
	mIsAsync = YES;

	NSInvocation* i = [self recoveryInvocation: delegate selector: didRecoverSelector contextInfo: contextInfo];
	[self setRecoveryInvocation: i];
	
	[mConnection setDelegate: self];
	[mNotifyConnection setDelegate: self];
	[mConnection resetAsync];
	[mNotifyConnection resetAsync];
}


- (void) PGTSConnectionFailed: (PGTSConnection *) connection
{
	[self waitForConnection];
}


- (void) PGTSConnectionEstablished: (PGTSConnection *) connection
{
	[self waitForConnection];
}
@end
