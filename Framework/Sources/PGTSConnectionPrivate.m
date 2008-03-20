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
#import <openssl/ssl.h>
#import <Log4Cocoa/Log4Cocoa.h>
#import "postgresql/libpq-fe.h"
#import "TSRunloopMessenger.h"
#import "PGTSConnectionPrivate.h"
#import "PGTSConstants.h"
#import "PGTSFunctions.h"
#import "PGTSConnectionDelegate.h"
#import "PGTSConnectionPool.h"
#import "PGTSExceptions.h"
#import "PGTSFunctions.h"


static int sslConnectionExIndex = -1;

extern int PGTSVerifySSLCertificate (int preverify_ok, X509_STORE_CTX* x509_ctx);

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

int
PGTSSSLConnectionExIndex ()
{
	if (-1 == sslConnectionExIndex)
		sslConnectionExIndex = SSL_get_ex_new_index (0, NULL, NULL, NULL, NULL);
	return sslConnectionExIndex;
}


static void 
DataAvailable (CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void* data, void* info)
{
	[(id) info dataAvailable];
}


@interface NSObject (PGTSKeyValueObserving)
+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *) key;
- (void) willChangeValueForKey: (NSString *) key;
- (void) didChangeValueForKey: (NSString *) key;
@end


#if 0
//Check for key-value observing capability.
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
	connecting = NO;
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
        [delegate PGTSConnection: self receivedNotice: notification];

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
			NSException* exception = [PGTSQueryException exceptionWithName: kPGTSQueryFailedException 
																	reason: [result errorMessage] 
																  userInfo: userInfo];
            [exception raise];
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

- (void) setErrorMessage: (NSString *) aMessage
{
	if (errorMessage != aMessage)
	{
		[errorMessage release];
		errorMessage = [aMessage retain];
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
    NSString* message = nil;
    [workerProxy endCopyAndAccept2: [delegate PGTSConnection: self acceptCopyingData: data errorMessage: &message]
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
- (void) workerThreadMain: (NSConditionLock *) threadStartLock
{
    [workerThreadLock lock];
	[threadStartLock lock];
    NSAutoreleasePool* threadPool = [[NSAutoreleasePool alloc] init];
    socket = NULL;
	socketSource = NULL;
    
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
    
    [threadStartLock unlockWithCondition: 1];
    
    while (haveInputSources && shouldContinueThread)
    {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        haveInputSources = [runLoop runMode: mode
                                 beforeDate: [NSDate distantFuture]];
		[pool release];
    }
	workerProxy = nil;
    returningWorkerProxy = nil;
	[self workerCleanUpDisconnecting: YES];
	
    log4Debug (@"Worker: exiting");
    [threadPool release];    
    
    [workerThreadLock unlock];
}


/**
 * Connect or reconnect to the database
 */
- (BOOL) workerPollConnectionResetting: (BOOL) reset
{
	[asyncConnectionLock lock];
    fd_set mask;    
    struct timeval ltimeout = timeout;
    int selectStatus = 0;
    BOOL rval = NO;
    BOOL stop = NO;
    PostgresPollingStatusType pollingStatus = PGRES_POLLING_WRITING; //Start with this
    PostgresPollingStatusType (* pollFunction)(PGconn *) = (reset ? &PQresetPoll : &PQconnectPoll);
    int bsdSocket = PQsocket (connection);
    
    if (bsdSocket < 0)
	{
        log4Info (@"Unable to get connection socket from libpq");
	}
    else
    {
		sslSetUp = NO;
		[self workerCleanUpDisconnecting: NO];
        
        //Polling loop
        while (1)
        {
            ltimeout = timeout;
            FD_ZERO (&mask);
            FD_SET (bsdSocket, &mask);
            selectStatus = 0;
            pollingStatus = pollFunction (connection);
			
			log4Debug (@"Polling status: %d connection status: %d", pollingStatus, PQstatus (connection));
#ifdef USE_SSL
			if (NO == sslSetUp && CONNECTION_SSL_CONTINUE == PQstatus (connection))
			{
				sslSetUp = YES;
				SSL* ssl = PQgetssl (connection);
				log4AssertValueReturn (NULL != ssl, NO, @"Expected ssl struct not to be NULL.");
				SSL_set_verify (ssl, SSL_VERIFY_PEER, &PGTSVerifySSLCertificate);
				SSL_set_ex_data (ssl, PGTSSSLConnectionExIndex (), self);
			}
#endif
			
            switch (pollingStatus)
            {
                case PGRES_POLLING_OK:
                    rval = YES;
					//Fall through
                case PGRES_POLLING_FAILED:
                    stop = YES;
                    break;
					
				case PGRES_POLLING_ACTIVE:
					//Select returns 0 on timeout
					selectStatus = 1;
					break;
                    
                case PGRES_POLLING_READING:
                    selectStatus = select (bsdSocket + 1, &mask, NULL, NULL, &ltimeout);
                    break;
                    
                case PGRES_POLLING_WRITING:
                default:					
                    selectStatus = select (bsdSocket + 1, NULL, &mask, NULL, &ltimeout);
                    break;
            } //switch

            [self updateConnectionStatus];
			
			if (0 == selectStatus)
			{
#if 0 //FIXME: debugging
				[self setErrorMessage: NSLocalizedString (@"Connection timed out.", @"Error message for connection failure")];
#endif
				break;
			}
            else if (0 >= selectStatus || YES == stop)
			{
                break;
			}
        }
        
        if (YES == rval && CONNECTION_OK == connectionStatus)
        {
            PQsetnonblocking (connection, 0); //We don't want to call PQsendquery etc. multiple times
            PQsetClientEncoding (connection, "UNICODE"); //Use UTF-8
			PQexec (connection, "SET standard_conforming_strings TO true");
			PQexec (connection, "SET datestyle TO 'ISO, YMD'");
            //FIXME: set other things as well?
            PQsetNoticeProcessor (connection, &PGTSNoticeProcessor, (void *) self);
			
			CFSocketContext context = {0, self, NULL, NULL, NULL};
			socket = CFSocketCreateWithNative (NULL, bsdSocket, kCFSocketReadCallBack, &DataAvailable, &context);
			CFSocketSetSocketFlags (socket, ~kCFSocketCloseOnInvalidate & CFSocketGetSocketFlags (socket));
			socketSource = CFSocketCreateRunLoopSource (NULL, socket, 0);
			log4AssertLog (NULL != socket, @"Expected source to have been created.");
			log4AssertLog (TRUE == CFSocketIsValid (socket), @"Expected socket to be valid.");
			log4AssertLog (NULL != socketSource, @"Expected socketSource to have been created.");
			log4AssertLog (TRUE == CFRunLoopSourceIsValid (socketSource), @"Expected socketSource to be valid.");
			
			CFRunLoopRef rl = CFRunLoopGetCurrent ();
			CFStringRef mode = kCFRunLoopCommonModes;
			log4AssertLog (FALSE == CFRunLoopContainsSource (rl, socketSource, mode), 
						   @"Expected run loop not to have socketSource.");
			CFRunLoopAddSource (rl, socketSource, mode);
			log4AssertLog (TRUE == CFRunLoopContainsSource (rl, socketSource, mode), 
						   @"Expected run loop to have socketSource.");
			
            cancelRequest = PQgetCancel (connection);
        }
    }
    
    if (messageDelegateAfterConnecting)
        [mainProxy sendFinishedConnectingMessage: connectionStatus reconnect: reset];
    [asyncConnectionLock unlockWithCondition: 1];

    return rval;
}

- (void) workerEnd
{
    //Setting the variable from the main thread isn't enough;
	//we also need to cause some action in worker's run loop by invoking this method.
	shouldContinueThread = NO;
    log4Debug (@"workerEnd");
}

- (void) workerCleanUpDisconnecting: (BOOL) disconnect
{
	[connectionLock lock];
	if (NULL != socketSource)
	{
		//CFRunLoopRemoveSource (CFRunLoopGetCurrent (), socketSource, kCFRunLoopCommonModes);
		CFRunLoopSourceInvalidate (socketSource);
		CFRelease (socketSource);
		socketSource = NULL;
	}
	if (NULL != socket)
	{
		//We have earlier set socket options so that it doesn't get closed automatically.
		//PQfinish does that for us.
		CFSocketInvalidate (socket);
		CFRelease (socket);
		socket = NULL;
	}
	if (NULL != cancelRequest)
	{
		PQfreeCancel (cancelRequest);
		cancelRequest = NULL;
	}
	if (disconnect && NULL != connection)
	{
		PQfinish (connection);
		connection = NULL;
	}
	[connectionLock unlock];
}

- (void) logQuery: (NSString *) query message: (BOOL) messageDelegate parameters: (NSArray *) parameters
{
    printf ("(%p) (%c) %s %s\n", self, messageDelegate ? 'A' : 'S', [[query description] UTF8String], [[parameters description] UTF8String]);
    //log4Info (@"(%p) %@ %@\n", self, query, parameters);
}

- (void) logNotice: (id) anObject
{
    log4Debug (@"(%p) %@", self, anObject);
}

- (void) logNotification: (id) anObject
{
    log4Debug (@"(%p) *** NOTIFY: %@\n", self, anObject);
}

/** Called when data is available from the libpq socket */
- (void) dataAvailable
{
	log4Debug (@"worker: availableData thread: %p", [NSThread currentThread]);
	[connectionLock lock];
	PQconsumeInput (connection);
	[self postPGnotifications];
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
- (void) updateConnectionStatus
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
		if (YES == allowKVO) [self didChangeValueForKey: @"connectionStatus"];
    }
}


@end
