//
// BXPGReconnectionRecoveryAttempter.m
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

#import "BXPGReconnectionRecoveryAttempter.h"
#import "BXPGTransactionHandler.h"


@implementation BXPGReconnectionRecoveryAttempter
- (BOOL) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex
{
	BOOL retval = NO;
	NSError* localError = nil;
	if (0 == recoveryOptionIndex)
	{
		[[[mHandler interface] databaseContext] connectIfNeeded: &localError];
		retval = (! localError);
	}
	return retval;
}


- (void) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex 
						 delegate: (id) delegate didRecoverSelector: (SEL) didRecoverSelector contextInfo: (void *) contextInfo
{
	NSInvocation* i = [self recoveryInvocation: delegate selector: didRecoverSelector contextInfo: contextInfo];
	[self setRecoveryInvocation: i];
	
	PGTSConnection* connection = [mHandler connection];
	[connection setDelegate: self];
	[[[mHandler interface] databaseContext] connect: nil];
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
