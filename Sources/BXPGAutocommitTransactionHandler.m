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

#import "BXPGTransactionHandler.h"


@implementation BXPGAutocommitTransactionHandler (Connecting)
- (void) connectAsync
{
	[self prepareForConnecting];
	mSync = NO;
	
	NSString* connectionString = [self connectionString];
	[mConnection connectAsync: connectionString];
}


- (void) connectSync: (NSError **) outError
{
	ExpectV (outError);
	
	[self prepareForConnecting];
	mSync = YES;
	mSyncErrorPtr = outError;
	
	NSString* connectionString = nil; //FIXME: get this somehow.
	[mConnection connectSync: connectionString];
	
	//-finishedConnecting gets executed here.
	
	mSyncErrorPtr = NULL;
	return mConnectionSucceeded;
}


- (void) PGTSConnectionFailed: (PGTSConnection *) connection
{
	[self handleConnectionErrorFor: failedConnection];
}


- (void) PGTSConnectionEstablished: (PGTSConnection *) connection
{
	[self handleSuccess];
}


- (void) PGTSConnectionLost: (PGTSConnection *) connection error: (NSError *) error
{
	//FIXME: determine somehow, whether the error is recoverable by connection reset or not.
	if (0)
	{
		Class attempterClass = [BXPGAutocommitConnectionResetRecoveryAttempter class];
		error = [self duplicateError: error recoveryAttempterClass: attempterClass];
	}
	[mInterface connectionLost: self error: error];
}
@end


@implementation BXPGAutocommitTransactionHandler (Transactions)
- (void) rollback: (NSError **) outError
{
	ExpectV (outError);
	
    //The locked key should be cleared in any case to cope with the situation
    //where the lock was acquired  after the last savepoint and the same key 
    //is to be locked again.
	if (PQTRANS_IDLE != [mConnection transactionStatus])
	{
		PGTSResultSet* res = [mConnection executeQuery: @"ROLLBACK; SELECT baseten.ClearLocks ();"];
		*outError = [res error];
	}
	[self resetSavepointIndex];	
}
@end



@implementation BXPGAutocommitConnectionResetRecoveryAttempter
- (BOOL) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex
{
	BOOL retval = NO;
	if (0 == recoveryOptionIndex)
		retval = [mConnection resetSync];
	return retval;
}


- (void) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex 
						 delegate: (id) delegate didRecoverSelector: (SEL) didRecoverSelector contextInfo: (void *) contextInfo
{
	NSInvocation* i = [self recoveryInvocation: delegate selector: didRecoverSelector contextInfo: contextInfo];
	[self setRecoveryInvocation: i];
	
	[mConnection setDelegate: self];
	[mConnection resetAsync];
}


- (void) PGTSConnectionFailed: (PGTSConnection *) connection
{
	[mRecoveryInvocation invoke];
	[connection setDelegate: mHandler];
	[connection disconnect];
}


- (void) PGTSConnectionEstablished: (PGTSConnection *) connection
{
	BOOL status = YES;
	[mRecoveryInvocation setArgument: &status atIndex: 2];
	[mRecoveryInvocation invoke];
	[connection setDelegate: mHandler];
	
	//FIXME: check modification tables?
}
@end
