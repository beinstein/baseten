//
// BXPGInterface.h
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
#import <BaseTen/BaseTen.h>
#import <PGTS/PGTS.h>


@class BXPGNotificationHandler;


@interface BXPGInterface : NSObject <BXInterface, PGTSConnectionDelegate> 
{
    BXDatabaseContext* mContext; //Weak
	
	NSMutableSet* mObservedEntities;
	NSMutableDictionary* mObservers;
	
	BXPGTransactionHandler* mTransactionHandler;
}

- (BXDatabaseContext *) databaseContext;
- (BOOL) fetchForeignKeys: (NSError **) outError;
- (BOOL) addClearLocksHandler: (NSError **) outError;
- (void) addObserverClass: (Class) observerClass forResult: (PGTSResultSet *) res 
				lastCheck: (NSDate *) lastCheck error: (NSError **) outError;

@end


@interface BXPGInterface (ConnectionDelegate)
- (void) connectionSucceeded;
- (void) connectionFailed: (NSError *) error;
- (void) connectionLost: (BXPGTransactionHandler *) handler error: (NSError *) error;
- (void) connection: (PGTSConnection *) connection gotNotification: (PGTSNotification *) notification;
@end


@interface BXPGInterface (Transactions)
- (NSString *) savepointQuery;
- (NSString *) rollbackToSavepointQuery;
- (void) resetSavepointIndex;
- (unsigned int) savepointIndex;
- (void) internalRollback: (NSError **) outError;
@end
