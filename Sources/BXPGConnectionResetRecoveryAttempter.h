//
// BXPGConnectionResetRecoveryAttempter.h
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
#import "PGTS.h"
#import "BaseTen.h"
@class BXPGTransactionHandler;


@interface BXPGConnectionRecoveryAttempter : NSObject
{
@public
	BXPGTransactionHandler* mHandler;
	
@protected
	NSInvocation* mRecoveryInvocation;
}
- (void) setRecoveryInvocation: (NSInvocation *) anInvocation;
- (NSInvocation *) recoveryInvocation: (id) target selector: (SEL) selector contextInfo: (void *) contextInfo;

- (BOOL) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex;
- (void) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex 
						 delegate: (id) delegate didRecoverSelector: (SEL) didRecoverSelector contextInfo: (void *) contextInfo;
- (void) allowConnecting: (BOOL) allow;

//Used with the synchronous method.
- (BOOL) doAttemptRecoveryFromError: (NSError *) error outError: (NSError **) error;
//Used with the asynchronous method.
- (void) doAttemptRecoveryFromError: (NSError *) error;
- (void) attemptedRecovery: (BOOL) succeeded error: (NSError *) newError;
@end


@interface BXPGConnectionRecoveryAttempter (PGTSConnectionDelegate) <PGTSConnectionDelegate>
@end
