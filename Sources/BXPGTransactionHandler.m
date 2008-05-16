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
@end


@implementation BXPGTransactionHandler (Connecting)
- (NSString *) connectionString
{
	BXDatabaseContext* ctx = [mInterface databaseContext];
	NSURL* databaseURI = [ctx databaseURI];
	NSMutableDictionary* connectionDict = [databaseURI BXPGConnectionDictionary];

	enum BXSSLMode sslMode = [ctx sslMode];
	[connectionDict setValue: SSLMode (mode) forKey: kPGTSSSLModeKey];
	
	return [connectionDict PGTSConnectionString];
}


- (void) prepareForConnecting
{
	mSyncErrorPtr = NULL;
	
	if (! mConnection)
	{
		mConnection = [[PGTSConnection alloc] init];
		[mConnection setDelegate: self];
	}
	
	//FIXME: handle SSL.
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
	BXConnectionResetRecoveryAttempter* attempter = [[[aClass alloc] init] autorelease];
	attempter->mHandler = self;
	
	NSMutableDictionary* userInfo = [[[error userInfo] mutableCopy] autorelease];
	[userInfo setObject: attempter forKey: NSRecoveryAttempterErrorKey];
	//FIXME: set the recovery options from attempter's class method or something.
	return [NSError errorWithDomain: [error domain] code: [error code] userInfo: aDict];
}


- (void) handleSuccess
{
	mConnectionSucceeded = YES;
	if (mAsync)
		[mInterface connectionSucceeded];
}	


- (void) connectSync: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
}


- (void) connectAsync
{
	[self doesNotRecognizeSelector: _cmd];
}
@end


@implementation BXPGTransactionHandler (Transactions)
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
	[self doesNotRecognizeSelector: _cmd];
}
@end


@implementation BXPGTransactionHandler (PGTSConnectionDelegate)
- (void) PGTSConnection: (PGTSConnection *) connection gotNotification: (PGTSNotification *) notification
{
	[mInterface PGTSConnection: connection gotNotification: notification];
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



@implementation BXPGConnectionResetRecoveryAttempter
- (void) dealloc
{
	[mRecoveryInvocation release];
	[super dealloc];
}


- (BOOL) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (void) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex 
						 delegate: (id) delegate didRecoverSelector: (SEL) didRecoverSelector contextInfo: (void *) contextInfo
{
	[self doesNotRecognizeSelector: _cmd];
}


- (void) setRecoveryInvocation: (NSInvocation *) anInvocation
{
	if (mRecoveryInvocation != anInvocation)
	{
		[mRecoveryInvocation release];
		mRecoveryInvocation = [anInvocation retain];
	}
}


- (void) recoveryInvocation: (id) target selector: (SEL) selector contextInfo: (void *) contextInfo
{
	NSMethodSignature* sig = [target methodSignatureForSelector: selector];
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
	[invocation setTarget: target];
	[invocation setSelector: selector];
	[invocation setArgument: &contextInfo atIndex: 3];
	
	BOOL status = NO;
	[invocation setArgument: &status atIndex: 2];
	
	return invocation;
}
@end



@implementation BXPGConnectionResetRecoveryAttempter (PGTSConnectionDelegate)
- (void) PGTSConnection: (PGTSConnection *) connection gotNotification: (PGTSNotification *) notification
{
	[self doesNotRecognizeSelector: _cmd];
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
