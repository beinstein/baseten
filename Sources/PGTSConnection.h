//
// PGTSConnection.h
// BaseTen
//
// Copyright (C) 2008 Marko Karppinen & Co. LLC.
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

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <BaseTen/postgresql/libpq-fe.h>
#import "PGTSCertificateVerificationDelegate.h"
@class PGTSConnection;
@class PGTSResultSet;
@class PGTSConnector;
@class PGTSQueryDescription;
@class PGTSDatabaseDescription;
@class PGTSNotification;
@protocol PGTSConnectorDelegate;


@protocol PGTSConnectionDelegate <NSObject>
- (void) PGTSConnectionFailed: (PGTSConnection *) connection;
- (void) PGTSConnectionEstablished: (PGTSConnection *) connection;
- (void) PGTSConnectionLost: (PGTSConnection *) connection error: (NSError *) error;
- (void) PGTSConnection: (PGTSConnection *) connection gotNotification: (PGTSNotification *) notification;
- (void) PGTSConnection: (PGTSConnection *) connection receivedNotice: (NSError *) notice;
@end


@interface PGTSConnection : NSObject
{
	PGconn* mConnection;
	NSMutableArray* mQueue;
	id mConnector;
    PGTSDatabaseDescription* mDatabase;
    NSMutableDictionary* mPGTypes;
	id <PGTSCertificateVerificationDelegate> mCertificateVerificationDelegate;
    
    CFRunLoopRef mRunLoop;
    CFSocketRef mSocket;
    CFRunLoopSourceRef mSocketSource;
    
    id mDelegate;
	
	BOOL mDidDisconnectOnSleep;
	BOOL mProcessingNotifications;
}
- (id) init;
- (void) dealloc;
- (void) connectAsync: (NSString *) connectionString;
- (BOOL) connectSync: (NSString *) connectionString;
- (void) resetAsync;
- (BOOL) resetSync;
- (void) disconnect;
- (void) setDelegate: (id <PGTSConnectionDelegate>) anObject;
- (PGTSDatabaseDescription *) databaseDescription;
- (void) setDatabaseDescription: (PGTSDatabaseDescription *) aDesc;
- (id) deserializationDictionary;
- (NSString *) errorString;
- (ConnStatusType) connectionStatus;
- (PGTransactionStatusType) transactionStatus;
- (PGconn *) pgConnection;
- (int) backendPID;

- (id <PGTSCertificateVerificationDelegate>) certificateVerificationDelegate;
- (void) setCertificateVerificationDelegate: (id <PGTSCertificateVerificationDelegate>) anObject;
@end


@interface PGTSConnection (Queries)
- (PGTSResultSet *) executeQuery: (NSString *) queryString;
- (PGTSResultSet *) executeQuery: (NSString *) queryString parameters: (id) p1, ...;
- (PGTSResultSet *) executeQuery: (NSString *) queryString parameterArray: (NSArray *) parameters;
- (int) sendQuery: (NSString *) queryString delegate: (id) delegate callback: (SEL) callback;
- (int) sendQuery: (NSString *) queryString delegate: (id) delegate callback: (SEL) callback parameters: (id) p1, ...;
- (int) sendQuery: (NSString *) queryString delegate: (id) delegate callback: (SEL) callback parameterArray: (NSArray *) parameters;
- (int) sendQuery: (NSString *) queryString delegate: (id) delegate callback: (SEL) callback 
   parameterArray: (NSArray *) parameters userInfo: (id) userInfo;
@end
