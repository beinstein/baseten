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
#import "BXPGAdditions.h"
#import "BXDatabaseAdditions.h"
#import "BXInterface.h"
#import "BXPGConnectionResetRecoveryAttempter.h"
#import <PGTS/PGTSAdditions.h>


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
	[mConnection release];
	[mCertificateVerificationDelegate release];
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


- (NSError *) duplicateError: (NSError *) error recoveryAttempterClass: (Class) aClass
{
	BXPGConnectionResetRecoveryAttempter* attempter = [[[aClass alloc] init] autorelease];
	attempter->mHandler = self;
	
	NSMutableDictionary* userInfo = [[[error userInfo] mutableCopy] autorelease];
	[userInfo setObject: attempter forKey: NSRecoveryAttempterErrorKey];
	//FIXME: set the recovery options from attempter's class method or something.
	return [NSError errorWithDomain: [error domain] code: [error code] userInfo: userInfo];
}


- (void) handleSuccess
{
	mConnectionSucceeded = YES;
	if (mAsync)
		[mInterface connectionSucceeded];
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
			PGTSResultSet* res = [mConnection executeQuery: @"BEGIN"];
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
@end


@implementation BXPGTransactionHandler (PGTSConnectionDelegate)
- (void) PGTSConnection: (PGTSConnection *) connection gotNotification: (PGTSNotification *) notification
{
	[mInterface connection: connection gotNotification: notification];
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
