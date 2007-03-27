//
// PGTSConnection.h
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
#import <sys/time.h>
#import <PGTS/postgresql/libpq-fe.h>



@class PGTSResultSet;
@class PGTSDatabaseInfo;
@class TSObjectTagDictionary;
@protocol PGTSConnectionDelegate;
@protocol PGTSCertificateVerificationDelegate;


@interface PGTSConnection : NSObject 
{
    @public
    unsigned int exceptionTable;

    @protected
	PGconn* connection;			//Deallocated in disconnect
    PGcancel* cancelRequest;	//Deallocated in disconnect
    
    NSFileHandle* socket;											//Deallocated in workerThreadMain
    volatile PGTSConnection *workerProxy, *returningWorkerProxy;	//Deallocated in workerThreadMain
	volatile PGTSConnection *mainProxy, *returningMainProxy;		//Deallocated in endWorkerThread
	
    PGTSDatabaseInfo* databaseInfo; //Weak
	Class resultSetClass;			//Weak
    id delegate;					//Weak

    NSNotificationCenter* postgresNotificationCenter;
    NSCountedSet* notificationCounts;
    NSMutableDictionary* notificationAssociations;

	NSLock* connectionLock;	
    NSLock* asyncConnectionLock;
    NSLock* workerThreadLock;
	
    NSString* connectionString;
    TSObjectTagDictionary* parameterCounts;
    NSMutableDictionary* deserializationDictionary;
    NSString* initialCommands;

	volatile ConnStatusType connectionStatus;
    struct timeval timeout;
	
	NSString* errorMessage;
	
	id <PGTSCertificateVerificationDelegate> certificateVerificationDelegate;

	BOOL connectsAutomatically;
    BOOL reconnectsAutomatically;
    BOOL overlooksFailedQueries;
    BOOL delegateProcessesNotices;
	
    volatile BOOL logsQueries;
	volatile BOOL shouldContinueThread;
    volatile BOOL threadRunning;
    volatile BOOL failedToSendQuery;
	
    volatile BOOL messageDelegateAfterConnecting;
	volatile BOOL sslSetUp;
	BOOL connecting;
	BOOL connectingAsync;
}

+ (PGTSConnection *) connection;
- (id) disconnectedCopy;

- (ConnStatusType) connect;
- (ConnStatusType) reconnect;
- (void) disconnect;

//FIXME: this could be named differently
- (void) endWorkerThread;

- (BOOL) connectAsync;
- (BOOL) reconnectAsync;

- (NSNotificationCenter *) postgresNotificationCenter;
- (void) startListening: (id) anObject forNotification: (NSString *) notificationName selector: (SEL) aSelector;
- (void) startListening: (id) anObject forNotification: (NSString *) notificationName 
               selector: (SEL) aSelector sendQuery: (BOOL) sendQuery;
- (void) stopListening: (id) anObject forNotification: (NSString *) notificationName;
- (void) stopListening: (id) anObject;

@end


@interface PGTSConnection (MiscAccessors)
+ (BOOL) hasSSLCapability;

- (PGconn *) pgConnection;
- (BOOL) setConnectionURL: (NSURL *) url;
- (void) setConnectionDictionary: (NSDictionary *) userDict;
- (void) setConnectionString: (NSString *) connectionString;
- (NSString *) connectionString;

- (BOOL) overlooksFailedQueries;
- (void) setOverlooksFailedQueries: (BOOL) aBool;
- (id <PGTSConnectionDelegate>) delegate;
- (void) setDelegate: (id <PGTSConnectionDelegate>) anObject;

- (BOOL) connectsAutomatically;
- (void) setConnectsAutomatically: (BOOL) aBool;
- (NSString *) initialCommands;
- (void) setInitialCommands: (NSString *) aString;

- (ConnStatusType) status;

- (struct timeval) timeout;
- (void) setTimeout: (struct timeval) value;

- (PGTSDatabaseInfo *) databaseInfo;
- (void) setDatabaseInfo: (PGTSDatabaseInfo *) anObject;
- (NSMutableDictionary *) deserializationDictionary;
- (void) setDeserializationDictionary: (NSMutableDictionary *) aDictionary;

- (void) setLogsQueries: (BOOL) aBool;
- (BOOL) logsQueries;

- (id <PGTSCertificateVerificationDelegate>) certificateVerificationDelegate;
- (void) setCertificateVerificationDelegate: (id <PGTSCertificateVerificationDelegate>) anObject;

- (BOOL) connectingAsync;
@end


@interface PGTSConnection (StatusMethods)
- (BOOL) connected;
- (NSString *) databaseName;
- (NSString *) user;
- (NSString *) password;
- (NSString *) host;
- (long) port;
- (NSString *) commandLineOptions;
- (ConnStatusType) connectionStatus;
- (PGTransactionStatusType) transactionStatus;
- (PGConnectionErrorCode) errorCode;
- (NSString *) statusOfParameter: (NSString *) parameterName;
- (int) protocolVersion;
- (int) serverVersion;
- (NSString *) errorMessage;
- (int) backendPID;
- (void *) sslStruct;
@end


@interface PGTSConnection (TransactionHandling)
- (BOOL) beginTransaction;
- (BOOL) commitTransaction;
- (BOOL) rollbackTransaction;
- (BOOL) rollbackToSavepointNamed: (NSString *) aName;
- (BOOL) savepointNamed: (NSString *) aName;
@end


@interface PGTSConnection (QueriesMainThread)

- (PGTSResultSet *) executeQuery: (NSString *) queryString;
- (PGTSResultSet *) executeQuery: (NSString *) queryString parameterArray: (NSArray *) parameters;
- (PGTSResultSet *) executeQuery: (NSString *) queryString parameters: (id) p1, ...;
- (PGTSResultSet *) executePrepareQuery: (NSString *) queryString name: (NSString *) aName;
- (PGTSResultSet *) executePrepareQuery: (NSString *) queryString name: (NSString *) aName 
                         parameterTypes: (Oid *) types;
- (PGTSResultSet *) executePreparedQuery: (NSString *) aName;
- (PGTSResultSet *) executePreparedQuery: (NSString *) aName parameters: (id) p1, ...;
- (PGTSResultSet *) executePreparedQuery: (NSString *) aName parameterArray: (NSArray *) parameters;
- (PGTSResultSet *) executeCopyData: (NSData *) data;
- (PGTSResultSet *) executeCopyData: (NSData *) data packetSize: (int) packetSize;
- (NSData *) executeReceiveCopyData;

- (int) sendQuery: (NSString *) queryString;
- (int) sendQuery: (NSString *) queryString parameterArray: (NSArray *) parameters;
- (int) sendQuery: (NSString *) queryString parameters: (id) p1, ...;
- (int) prepareQuery: (NSString *) queryString name: (NSString *) aName;
- (int) prepareQuery: (NSString *) queryString name: (NSString *) aName types: (Oid *) types;
- (int) sendPreparedQuery: (NSString *) aName parameters: (id) p1, ...;
- (int) sendPreparedQuery: (NSString *) aName parameterArray: (NSArray *) parameters;
- (void) sendCopyData: (NSData *) data;
- (void) sendCopyData: (NSData *) data packetSize: (int) packetSize;
- (void) receiveCopyData;

- (void) cancelCommand;

@end


@interface PGTSConnection (QueriesWorkerThread)
- (int) sendQuery2: (NSString *) queryString messageDelegate: (BOOL) messageDelegate;
- (int) sendQuery2: (NSString *) queryString parameterArray: (NSArray *) parameters
   messageDelegate: (BOOL) messageDelegate;
- (int) prepareQuery2: (NSString *) queryString name: (NSString *) aName
       parameterCount: (int) count parameterTypes: (Oid *) types messageDelegate: (BOOL) messageDelegate;
- (int) sendPreparedQuery2: (NSString *) aName parameterArray: (NSArray *) arguments 
           messageDelegate: (BOOL) messageDelegate;

- (int) sendCopyData2: (NSData *) data packetSize: (int) packetSize messageWhenDone: (BOOL) messageWhenDone;
- (int) endCopyAndAccept2: (BOOL) accept errorMessage: (NSString *) errorMessage messageWhenDone: (BOOL) messageWhenDone;
- (int) receiveRetainedCopyData2: (volatile NSData **) dataPtr;
- (void) receiveCopyDataAndSendToDelegate;

- (void) retrieveResultsAndSendToDelegate;
- (NSArray *) pendingResultSets;

@end


@interface PGTSConnection (NSCoding) <NSCoding>
@end
