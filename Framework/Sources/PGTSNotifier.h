//
// PGTSNotifier.h
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
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
@class PGTSTableInfo;
@class PGTSConnection;


@interface PGTSNotifier : NSObject 
{
    PGTSConnection* connection;
    NSCountedSet* observedTables;
	NSCountedSet* postedNotifications;
    id notificationNames; //From Postgres
	NSMutableDictionary* lastChecks;
    NSArray* sentNotifications;
    id delegate;
	BOOL delegateDecidesNotificationPosting;
    BOOL observesSelfGenerated;
}

- (BOOL) observeTable: (PGTSTableInfo *) tableInfo selector: (SEL) aSelector
	 notificationName: (NSString *) notificationName;
- (BOOL) observeTable: (PGTSTableInfo *) tableInfo selector: (SEL) aSelector 
	 notificationName: (NSString *) notificationName notificationQuery: (NSString *) query;
- (void) removeObserverForTable: (PGTSTableInfo *) tableInfo 
			   notificationName: (NSString *) notificationName;

- (void) setObservesSelfGenerated: (BOOL) aBool;
- (BOOL) observesSelfGenerated;
- (NSDate *) lastCheckForTable: (NSString *) table;
- (void) setLastCheck: (NSDate *) date forTable: (NSString *) table;
- (void) removeNotificationIfNeeded: (PGTSTableInfo *) tableInfo;
- (NSArray *) sentNotifications;

- (BOOL) observe: (NSNotification *) notification;

- (PGTSConnection *) connection;
- (void) setConnection: (PGTSConnection *) aConnection;

- (BOOL) shouldHandleNotification: (NSNotification *) notification;
- (void) setDelegate: (id) anObject;

@end
