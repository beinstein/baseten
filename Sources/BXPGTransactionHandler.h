//
// BXPGTransactionHandler.h
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

#import <Foundation/Foundation.h>
#import <PGTS/PGTS.h>
#import "BXPGInterface.h"


@interface BXPGTransactionHandler : NSObject 
{
	BXPGInterface* mInterface; //Weak.
	PGTSConnection* mConnection;
	NSUInteger mSavepointIndex;
	
	NSError** mSyncErrorPtr;
	BOOL mAsync;
	BOOL mConnectionSucceeded;
	
	BOOL mIsResetting;
}
- (void) connectAsync;
- (BOOL) connectSync: (NSError **) outError;
- (void) rollback: (NSError **) outError;

- (void) prepareForConnecting;
- (NSString *) connectionString;
- (NSError *) packErrorFor: (PGTSConnection *) failedConnection;
- (NSError *) duplicateError: (NSError *) error recoveryAttempterClass: (Class) aClass;
@end


@interface BXPGTransactionHandler (PGTSConnectionDelegate) <PGTSConnectionDelegate>
@end


@interface BXPGConnectionResetRecoveryAttempter : NSObject
{
	@public
	BXPGTransactionHandler* mHandler;
	
	@protected
	NSInvocation* mRecoveryInvocation;
}
- (void) setRecoveryInvocation: (NSInvocation *) anInvocation;
- (void) recoveryInvocation: (id) target selector: (SEL) selector contextInfo: (void *) contextInfo;

- (BOOL) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex;
- (void) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex 
						 delegate: (id) delegate didRecoverSelector: (SEL) didRecoverSelector contextInfo: (void *) contextInfo;
@end


@interface BXPGConnectionResetRecoveryAttempter (PGTSConnectionDelegate) <PGTSConnectionDelegate>
@end
