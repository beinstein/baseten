//
// PGTSConnectionPrivate.m
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


//#define LOG_ERRORS 1

#import <sys/types.h>
#import <sys/time.h>
#import <unistd.h>
#import "TSRunloopMessenger.h"
#import "PGTSConnectionPrivate.h"
#import "PGTSConstants.h"
#import "PGTSFunctions.h"
#import "PGTSConnectionDelegate.h"
#import "PGTSConnectionPool.h"
#import "PGTSExceptions.h"
#import <Log4Cocoa/Log4Cocoa.h>


static NSNotification* 
PGTSExtractPgNotification (id anObject, PGnotify* pgNotification)
{
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt: pgNotification->be_pid],       kPGTSBackendPIDKey,
        [NSNull null],                                          kPGTSNotificationExtraKey,
        //This doesn't work yet
        //[NSString stringWithUTF8String: pgNotification->extra],	kPGTSNotificationExtraKey, 
        nil];
    NSNotification* notification = [NSNotification notificationWithName: [NSString stringWithUTF8String: pgNotification->relname]
                                                                 object: anObject
                                                               userInfo: userInfo];
    return notification;
}


@interface NSObject (PGTSKeyValueObserving)
+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *) key;
- (void) willChangeValueForKey: (NSString *) key;
- (void) didChangeValueForKey: (NSString *) key;
@end

//FIXME: what is this?
#if 0
@interface NSObject (PGTSKVO)
+ (BOOL) PGTSAllowKVO;
@end

@implementation NSObject (PGTSKVO)
+ (BOOL) PGTSAllowKVO
{
    static BOOL tooLate = NO;
    static BOOL allow = NO;
    
    if (NO == tooLate)
    {
        tooLate = YES;
        allow = ([self instancesRespondToSelector: @selector (willChangeValueForKey:)] &&
                 [self instancesRespondToSelector: @selector (didChangeValueForKey:)]);
    }
    
    return allow;
}
@end
#endif


@implementation PGTSConnection (PrivateMethods)

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *) key
{
    BOOL rval = NO;
    if (NO == [@"connectionStatus" isEqualToString: key])
        rval = [super automaticallyNotifiesObserversForKey: key];
    return rval;
}

/**
 * Add the connection to the shared connection pool and send user specified initial SQL commands
 */
- (void) finishConnecting
{
    if (CONNECTION_OK != connectionStatus)
        [[PGTSConnectionPool sharedInstance] removeConnection: self];
    else
    {
        [[PGTSConnectionPool sharedInstance] addConnection: self];
        if (nil != initialCommands)
            [workerProxy sendQuery: initialCommands];
    }
}

/**
 * Notify the delegate about connection having been made or the attempt having failed
 */
- (void) sendFinishedConnectingMessage: (ConnStatusType) status reconnect: (BOOL) reconnected
{
    [self finishConnecting];
    if (messageDelegateAfterConnecting)
    {
        if (CONNECTION_OK == status)
        {
            if (reconnected)
                [delegate PGTSConnectionDidReconnect: self];
            else
                [delegate PGTSConnectionEstablished: self];
        }
        
        else
        {
            [delegate PGTSConnectionFailed: self];
        }
    }
}

/** 
 * Handle NOTICEs from PostgreSQL 
 * This is not the same thing as PostgreSQL notifications.
 */
- (void) handleNotice: (NSString *) message
{
    NSDictionary* userInfo = nil;
    NSNotification* notification = nil;
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys: 
        message, kPGTSNoticeMessageKey, nil];
    
    notification = [NSNotification notificationWithName: kPGTSNotice
                                                 object: self
                                               userInfo: userInfo];
    if (delegateProcessesNotices)
    {
        //[delegate PGTSConnection: nil receivedNotice: notification]; //FIXME: come up with a way to pass the connection object
        //update: I really cannot understand, what was supposed to be the problem with this. Can't I just use 'self'?
        [delegate PGTSConnection: self receivedNotice: notification];
    }
    [self logNotice: message];
}

- (void) raiseExceptionForMissingSelector: (SEL) aSelector
{
    NSString* reason = NSLocalizedString (@"Delegate does not respond to selector %@", @"Exception reason");
    [[NSException exceptionWithName: NSInternalInconsistencyException
                             reason: [NSString stringWithFormat: reason, NSStringFromSelector (aSelector)]
                           userInfo: nil] raise];
}

- (void) checkQueryStatus: (PGTSResultSet *) result async: (BOOL) async
{
    ExecStatusType status = [result status];
    if (NO == overlooksFailedQueries && (PGRES_BAD_RESPONSE == status || PGRES_FATAL_ERROR == status))
    {
        if ([delegate respondsToSelector: kPGTSReceivedErrorSelector])
            [delegate PGTSConnection: self receivedError: result];
        else if (YES == async && [delegate respondsToSelector: kPGTSReceivedResultSetSelector])
            [delegate PGTSConnection: self receivedResultSet: result];
        else
        {
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                result, kPGTSResultSetKey,
                self,   kPGTSConnectionKey,
                nil];
            [[PGTSQueryException exceptionWithName: kPGTSQueryFailedException reason: [result errorMessage] 
                                          userInfo: userInfo] raise];
        }
    }
}

- (PGTSResultSet *) resultFromProxy: (volatile PGTSConnection *) proxy status: (int) status
{
    PGTSResultSet* res = nil;
    if (YES == failedToSendQuery)
        [self handleFailedQuery];
    else if (1 == status)
    {
        NSArray* results = [proxy pendingResultSets];
        res = [results lastObject];
        [self checkQueryStatus: res async: NO];
    }
    return res;
}

- (int) sendResultsToDelegate: (int) status
{
    if (YES == failedToSendQuery)
        [self handleFailedQuery];
    else if (1 == status)
        [workerProxy retrieveResultsAndSendToDelegate];
    return status;
}


- (void) handleFailedQuery
{
    failedToSendQuery = NO;

    NSString* exceptionName = nil;
    SEL selector = NULL;
    ConnStatusType status = [self connectionStatus];
    
    if (CONNECTION_OK == status)
    {
        selector = kPGTSFailedToSendQuerySelector;
        exceptionName = kPGTSQueryFailedException;
    }
    else
    {
        selector = kPGTSConnectionFailedSelector;
        exceptionName = kPGTSConnectionFailedException;
    }

    if ([delegate respondsToSelector: selector])
    {
        if (CONNECTION_OK == status)
            [delegate PGTSConnection: self failedToSendQuery: nil];
        else
            [delegate PGTSConnectionFailed: self];
    }
    else
    {
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            self,   kPGTSConnectionKey,
            nil];
        [[NSException exceptionWithName: exceptionName
                                 reason: nil
                               userInfo: userInfo] raise];
    }    
}

@end


@implementation PGTSConnection (ProxyMethods)

/**
 * Send query dispatch status to the delegate
 * Afterwards collect the results and send them as well
 */
- (void) sendDispatchStatusToDelegate: (int) status forQuery: (NSString *) queryString
{
    if (0 == status)
        [delegate PGTSConnection: self failedToSendQuery: queryString];
    else
    {
        [delegate PGTSConnection: self sentQuery: queryString];
        [workerProxy retrieveResultsAndSendToDelegate];
    }
}

- (void) sendResultSetWithNotification: (NSNotification *) notification
{
    [[NSNotificationCenter defaultCenter] postNotification: notification];
}

- (void) succeededToCopyData: (NSData *) data
{
    NSString* errorMessage = nil;
    [workerProxy endCopyAndAccept2: [delegate PGTSConnection: self acceptCopyingData: data errorMessage: &errorMessage]
                      errorMessage: errorMessage messageWhenDone: YES];
}

- (void) succeededToReceiveData: (NSData *) data
{
    [delegate PGTSConnection: self receivedData: data];
}

/**
 * Send results to the delegate
 */
- (void) sendResultToDelegate: (PGTSResultSet *) result
{
    [self checkQueryStatus: result async: YES];
    [delegate PGTSConnection: self receivedResultSet: result];
}

@end


@implementation PGTSConnection (WorkerPrivateMethods)

/**
 * Run loop for the worker thread
 */
- (void) workerThreadMain: (NSLock *) threadStartLock
{
    [workerThreadLock lock];
    NSAutoreleasePool* threadPool = [[NSAutoreleasePool alloc] init];
    socket = nil;
    
    NSString* mode = NSDefaultRunLoopMode;
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
    BOOL haveInputSources = YES;
    
    shouldContinueThread = YES;
    threadRunning = YES;
    
    //Inter-thread messaging
    id runLoopMessenger  = [TSRunloopMessenger runLoopMessengerForCurrentRunLoop];
    workerProxy          = [runLoopMessenger target: self withResult: NO];
    returningWorkerProxy = [runLoopMessenger target: self withResult: YES];

    //Prevent the run loop from exiting immediately
    [runLoop addPort: [NSPort port] forMode: mode];
    
    [threadStartLock unlock];
    
    while (haveInputSources && shouldContinueThread)
    {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        haveInputSources = [runLoop runMode: mode
                                 beforeDate: [NSDate distantFuture]];
		[pool release];
    }
	workerProxy = nil;
    returningWorkerProxy = nil;
    socket = nil;
	
    log4Debug (@"Worker: exiting");
    [threadPool release];    
    
    [workerThreadLock unlock];
}

/**
 * Connect or reconnect to the database
 */
- (BOOL) workerPollConnectionResetting: (BOOL) reset
{
    fd_set mask;    
    struct timeval ltimeout = timeout;
    int selectStatus = 0;
    BOOL rval = NO;
    BOOL stop = NO;
    PostgresPollingStatusType pollingStatus = PGRES_POLLING_WRITING; //Start with this
    PostgresPollingStatusType (* pollFunction)(PGconn *) = (reset ? &PQresetPoll : &PQconnectPoll);
    int bsdSocket = PQsocket (connection);
    
    if (bsdSocket <= 0)
        log4Error (@"Unable to get connection socket from libpq");
    else
    {
        if (YES == reset)
        {
            [socket closeFile];
            [socket release];
            socket = nil;
        }
        
        //Polling loop
        while (1)
        {
            ltimeout = timeout;
            FD_ZERO (&mask);
            FD_SET (bsdSocket, &mask);
            selectStatus = 0;
            pollingStatus = pollFunction (connection);
            
            switch (pollingStatus)
            {
                case PGRES_POLLING_OK:
                    rval = YES;
                case PGRES_POLLING_FAILED:
                    stop = YES;
                    break;
                    
                case PGRES_POLLING_READING:
                    selectStatus = select (bsdSocket + 1, &mask, NULL, NULL, &ltimeout);
                    break;
                    
                case PGRES_POLLING_WRITING:
                default:
                    selectStatus = select (bsdSocket + 1, NULL, &mask, NULL, &ltimeout);
                    break;
            } //switch

            [self setConnectionStatus];
                            
            if (0 >= selectStatus || YES == stop)
                break;
        }
        
        if (YES == rval && CONNECTION_OK == connectionStatus)
        {
            PQsetnonblocking (connection, 0); //We don't want to call PQsendquery etc. multiple times
            PQsetClientEncoding (connection, "UNICODE"); //Use UTF-8
			PQexec (connection, "SET standard_conforming_strings TO true");
			PQexec (connection, "SET datestyle TO 'ISO, YMD'");
            //FIXME: set other things, such as the date format, as well
            PQsetNoticeProcessor (connection, &PGTSNoticeProcessor, (void *) self);

            socket = [[NSFileHandle alloc] initWithFileDescriptor: bsdSocket];
            [socket waitForDataInBackgroundAndNotify];
            [[NSNotificationCenter defaultCenter] addObserver: self 
                                                     selector: @selector (dataAvailableFromLib:)
                                                         name: NSFileHandleDataAvailableNotification 
                                                       object: socket];

            cancelRequest = PQgetCancel (connection);
        }
    }
    
    if (messageDelegateAfterConnecting)
        [mainProxy sendFinishedConnectingMessage: connectionStatus reconnect: reset];
    [asyncConnectionLock unlock];

    return rval;
}

- (void) workerEnd
{
    //Setting the variable from the main thread isn't enough;
	//we also need to cause some action in worker's run loop by invoking this method.
	shouldContinueThread = NO;
    log4Debug (@"workerEnd");
}

- (void) logQuery: (NSString *) query parameters: (NSArray *) parameters
{
    printf ("(%p) %s %s\n", self, [[query description] UTF8String], [[parameters description] UTF8String]);
    //log4Info (@"(%p) %@ %@\n", self, query, parameters);
}

- (void) logNotice: (id) anObject
{
    log4Info (@"(%p) NOTICE: %@", self, anObject);
}

- (void) logNotification: (id) anObject
{
    log4Debug (@"(%p) *** NOTIFY: %@\n", self, anObject);
}

/** Called when data is available from the libpq socket */
- (void) dataAvailableFromLib: (NSNotification *) aNotification
{
    log4Debug (@"worker: availableData thread: %p", [NSThread currentThread]);
    [connectionLock lock];
    PQconsumeInput (connection);
    [self postPGnotifications];
    [socket waitForDataInBackgroundAndNotify];
    [connectionLock unlock];
}

- (void) postPGnotifications
{
    PGnotify* pgNotification = NULL;
    while ((pgNotification = PQnotifies (connection)))
    {
        NSNotification* notification = PGTSExtractPgNotification (self, pgNotification);
        [self logNotification: [notification name]];
        log4Debug (@"Posting notification: %@", notification);
        [postgresNotificationCenter performSelectorOnMainThread: @selector (postNotification:)
                                                     withObject: notification
                                                  waitUntilDone: NO];
        PQfreeNotify (pgNotification);
    }
}

/** Set the connection status after we have made the connection */
- (void) setConnectionStatus
{
    //KVO is not available on Mac OS X 10.2
    static BOOL allowKVO = YES;
    ConnStatusType tempStatus = PQstatus (connection);
    if (tempStatus != connectionStatus)
    {
        if (YES == allowKVO)
        {
            NS_DURING
                [self willChangeValueForKey: @"connectionStatus"];
            NS_HANDLER
                if ([[localException name] isEqualToString: NSInvalidArgumentException])
                    allowKVO = NO;
                NS_ENDHANDLER
        }
            connectionStatus = tempStatus;
            log4Debug (@"ConnectionStatus: %d", connectionStatus);
            if (YES == allowKVO) [self didChangeValueForKey: @"connectionStatus"];
    }
}


@end
