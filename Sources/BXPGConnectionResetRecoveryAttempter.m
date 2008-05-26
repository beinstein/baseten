//
// BXPGConnectionResetRecoveryAttempter.m
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
#import "BXPGConnectionResetRecoveryAttempter.h"
#import "BXProbes.h"


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


- (NSInvocation *) recoveryInvocation: (id) target selector: (SEL) selector contextInfo: (void *) contextInfo
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

- (void) PGTSConnection: (PGTSConnection *) connection receivedNotice: (NSError *) notice
{
	//log4Debug (@"%p: %s", connection, message);
	if (BASETEN_RECEIVED_PG_NOTICE_ENABLED ())
	{
		NSString* message = [[notice userInfo] objectForKey: kPGTSErrorMessage];
		char* message_s = strdup ([message UTF8String]);
		BASETEN_RECEIVED_PG_NOTICE (connection, message_s);
		free (message_s);
	}
}
@end
