//
// PGTSConnectionPrivate.h
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

#import <PGTS/PGTSResultSet.h>
#import <PGTS/PGTSConnection.h>
#import <PGTS/PGTSConnectionDelegate.h>


#define kPGTSRaiseForAsync              (1 << 0)
#define kPGTSRaiseForCompletelyAsync    (1 << 1)
#define kPGTSRaiseOnFailedQuery         (1 << 2)
#define kPGTSRaiseForConnectAsync       (1 << 3)
#define kPGTSRaiseForReconnectAsync     (1 << 4)
#define kPGTSRaiseForReceiveCopyData    (1 << 5)
#define kPGTSRaiseForSendCopyData       (1 << 6)
    
#define LogQuery( QUERY, PARAMETERS ) { if (YES == logsQueries) [self logQuery: QUERY parameters: PARAMETERS]; }


@interface PGTSConnection (PrivateMethods)
+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *) key;
- (void) checkQueryStatus: (PGTSResultSet *) result async: (BOOL) async;
- (void) finishConnecting;
- (void) raiseExceptionForMissingSelector: (SEL) aSelector;
- (void) handleNotice: (NSString *) message;
- (void) sendFinishedConnectingMessage: (ConnStatusType) status reconnect: (BOOL) reconnected;
- (PGTSResultSet *) resultFromProxy: (volatile PGTSConnection *) proxy status: (int) status;
- (int) sendResultsToDelegate: (int) status;
- (void) handleFailedQuery;
@end


@interface PGTSConnection (ProxyMethods)
- (void) succeededToCopyData: (NSData *) data;
- (void) succeededToReceiveData: (NSData *) data;
- (void) sendDispatchStatusToDelegate: (int) status forQuery: (NSString *) queryString;
- (void) sendResultToDelegate: (PGTSResultSet *) result;
@end


@interface PGTSConnection (WorkerPrivateMethods)
- (void) workerThreadMain: (NSLock *) threadLock;
- (BOOL) workerPollConnectionResetting: (BOOL) reset;
- (void) workerEnd;
- (void) logQuery: (NSString *) query parameters: (NSArray *) parameters;
- (void) logNotice: (id) anObject;
- (void) logNotification: (id) anObject;
- (void) postPGnotifications;
- (void) setConnectionStatus;
@end
