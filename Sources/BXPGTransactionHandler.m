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

#import "BXPGTransactionHandler.h"


@implementation BXPGTransactionHandler
- (NSString *) savepointQuery
{
    mSavepointIndex++;
    return [NSString stringWithFormat: @"SAVEPOINT BXPGSavepoint%u", mSavepointIndex];
}

- (NSString *) rollbackToSavepointQuery
{
	mSavepointIndex++;
    return [NSString stringWithFormat: @"SAVEPOINT BXPGSavepoint%u", mSavepointIndex];
}

- (void) resetSavepointIndex
{
	mSavepointIndex = 0;
}

- (NSUInteger) savepointIndex
{
	return mSavepointIndex;
}

- (void) rollback: (NSError **) outError
{
}
@end


@implementation BXPGAutocommitTransactionHandler
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


@implementation BXPGManualCommitTransactionHandler
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
