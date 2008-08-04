//
// BXPGManualCommitConnectionResetRecoveryAttempter.m
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
#import "BXPGManualCommitConnectionResetRecoveryAttempter.h"
#import "BXPGManualCommitTransactionHandler.h"
#import "BXLogger.h"


@implementation BXPGManualCommitConnectionResetRecoveryAttempter
- (void) dealloc
{
	[mSyncError release];
	[super dealloc];
}

- (BOOL) doAttemptRecoveryFromError: (NSError *) error outError: (NSError **) outError
{
	ExpectR (outError, NO);
	PGTSConnection* connection = [mHandler connection];
	PGTSConnection* notifyConnection = [(id) mHandler notifyConnection];
	
	[connection setDelegate: self];
	[notifyConnection setDelegate: self];

	[connection resetSync];
	[notifyConnection resetSync];
	
	//-finishedConnecting gets executed here.	
	
	if (! mSucceeded)
		*outError = mSyncError;
	
	return mSucceeded;
}


- (void) doAttemptRecoveryFromError: (NSError *) error
{
	mCounter = 2;
	mIsAsync = YES;
	
	PGTSConnection* connection = [mHandler connection];
	PGTSConnection* notifyConnection = [(id) mHandler notifyConnection];
	[connection setDelegate: self];
	[notifyConnection setDelegate: self];
	[connection resetAsync];
	[notifyConnection resetAsync];
}


- (void) finishedConnecting
{
	PGTSConnection* connection = [mHandler connection];
	PGTSConnection* notifyConnection = [(id) mHandler notifyConnection];
	
	ConnStatusType s1 = [connection connectionStatus];
	ConnStatusType s2 = [notifyConnection connectionStatus];
	mSucceeded = (CONNECTION_OK == s1 && CONNECTION_OK == s2);
	
	NSError* error1 = nil;
	NSError* error2 = nil;
	
	if (! mSucceeded)
	{
		error1 = [connection connectionError];
		error2 = [notifyConnection connectionError];
		mSyncError = [(error1 ?: error2) retain];
		
		[connection disconnect];
		[notifyConnection disconnect];
	}
	else
	{
		[connection setDelegate: mHandler];
		[notifyConnection setDelegate: mHandler];
	}
	
	if (mIsAsync)
	{
		[self attemptedRecovery: mSucceeded error: mSyncError];
		//FIXME: check modification tables?
		//FIXME: clear mHandlingConnectionLoss.
	}
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
@end
