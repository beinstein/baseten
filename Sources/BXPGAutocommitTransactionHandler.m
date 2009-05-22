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

#import "BXPGInterface.h"
#import "BXPGAutocommitTransactionHandler.h"
#import "BXPGAutocommitConnectionResetRecoveryAttempter.h"
#import "BXPGReconnectionRecoveryAttempter.h"
#import "BXPGAdditions.h"
#import "BXProbes.h"
#import "BXLogger.h"


@implementation BXPGAutocommitTransactionHandler
- (void) markLocked: (BXEntityDescription *) entity 
	  relationAlias: (NSString *) alias
		 fromClause: (NSString *) fromClause
		whereClause: (NSString *) whereClause 
		 parameters: (NSArray *) parameters
		 willDelete: (BOOL) willDelete
{
	[self markLocked: entity 
	   relationAlias: alias
		  fromClause: fromClause
		 whereClause: whereClause 
		  parameters: parameters
		  willDelete: willDelete
		  connection: mConnection 
	notifyConnection: mConnection];
}
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
	
	NSDictionary* connectionDictionary = [self connectionDictionary];
	[mConnection connectAsync: connectionDictionary];
}


- (BOOL) connectSync: (NSError **) outError
{
	ExpectR (outError, NO);
	
	[self prepareForConnecting];
	mAsync = NO;
	mSyncErrorPtr = outError;
	
	NSDictionary* connectionDictionary = [self connectionDictionary];
	[mConnection connectSync: connectionDictionary];
	
	//-finishedConnecting gets executed here.
	
	mSyncErrorPtr = NULL;
	return mConnectionSucceeded;
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
- (BOOL) savepointIfNeeded: (NSError **) outError
{
	return YES;
}


- (BOOL) beginSubTransactionIfNeeded: (NSError **) outError
{
	return [self beginIfNeeded: outError];
}


- (void) beginAsyncSubTransactionFor: (id) delegate callback: (SEL) callback userInfo: (NSDictionary *) userInfo
{
	[self beginIfNeededFor: delegate callback: callback userInfo: userInfo];
}


- (BOOL) endSubtransactionIfNeeded: (NSError **) outError
{
	return [self save: outError];
}


- (void) rollbackSubtransaction
{
	//FIXME: consider whether we need an error pointer here or just assert that the query succeeds.
	NSError* localError = nil;
	[self rollback: &localError];
	BXAssertLog (! localError, @"Expected rollback to savepoint succeed. Error: %@", localError);
}


- (BOOL) autocommits
{
	return YES;
}
@end
