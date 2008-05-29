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


@implementation BXPGManualCommitConnectionResetRecoveryAttempter
- (BOOL) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex
{
	if (0 == recoveryOptionIndex)
	{
		[[mHandler connection] resetSync];
		[[(id) mHandler notifyConnection] resetSync];
		//-finishedConnecting gets executed here.
	}
	
	[self allowConnecting: mSucceeded];
	return mSucceeded;
}


- (void) finishedConnecting
{
	PGTSConnection* connection = [mHandler connection];
	PGTSConnection* notifyConnection = [(id) mHandler notifyConnection];
	
	ConnStatusType s1 = [connection connectionStatus];
	ConnStatusType s2 = [notifyConnection connectionStatus];
	mSucceeded = (CONNECTION_OK == s1 && CONNECTION_OK == s2);
	
	if (! mSucceeded)
	{
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
		[self allowConnecting: mSucceeded];
		[mRecoveryInvocation setArgument: &mSucceeded atIndex: 2];
		[mRecoveryInvocation invoke];
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


- (void) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex 
						 delegate: (id) delegate didRecoverSelector: (SEL) didRecoverSelector contextInfo: (void *) contextInfo
{
	mCounter = 2;
	mIsAsync = YES;
	
	NSInvocation* i = [self recoveryInvocation: delegate selector: didRecoverSelector contextInfo: contextInfo];
	[self setRecoveryInvocation: i];
	
	PGTSConnection* connection = [mHandler connection];
	PGTSConnection* notifyConnection = [(id) mHandler notifyConnection];
	[connection setDelegate: self];
	[notifyConnection setDelegate: self];
	[connection resetAsync];
	[notifyConnection resetAsync];
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
