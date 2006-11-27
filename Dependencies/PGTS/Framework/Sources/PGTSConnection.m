//
// PGTSConnection.m
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

#import <PGTS/postgresql/libpq-fe.h> 

#ifdef USE_SSL
#import <openssl/ssl.h>
#endif

#import "TSRunloopMessenger.h"

#define USE_ASSERTIONS 1

#import <PGTS/PGTSConnectionPrivate.h>
#import <PGTS/PGTSConnection.h>
#import <PGTS/PGTSResultSetPrivate.h>
#import <PGTS/PGTSResultSet.h>
#import <PGTS/PGTSAdditions.h>
#import <PGTS/PGTSConnectionPool.h>
#import <PGTS/PGTSConstants.h>
#import <PGTS/PGTSConnectionDelegate.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSDatabaseInfo.h>
#import <TSDataTypes/TSDataTypes.h>


/** \cond */

#define BlockWhileConnecting( CONNECTION_CALL ) { \
    messageDelegateAfterConnecting = NO; \
    [asyncConnectionLock lock]; \
    \
    if (YES == CONNECTION_CALL) \
        [asyncConnectionLock lock]; \
    \
    [asyncConnectionLock unlock]; \
    messageDelegateAfterConnecting = YES; \
    [self finishConnecting]; \
}


#define AssociateSelector( SEL, EXCEPTBIT ) { selector: SEL, exceptBit: EXCEPTBIT }


struct exceptionAssociation
{
    SEL selector;
    int exceptBit;
};

/** \endcond */


/**
 * Return the result of the given accessor as an NSString
 * Handles returned NULL values safely
 */
static inline NSString*
SafeStatusAccessor (char* (*function)(const PGconn*), PGconn* connection)
{
    char* value = function (connection);
    NSString* rval = nil;
    if (NULL != value)
        rval = [NSString stringWithUTF8String: value];
    return rval;
}

/**
 * Raise an exception if the delegate is invalid
 * Checks from a cache whether the delegate responds to a given selector
 * and raises and exception if needed
 */
static void
CheckExceptionTable (PGTSConnection* sender, int bitMask, BOOL doCheck)
{
    if (doCheck && sender->exceptionTable & bitMask)
    {
        id delegate = [sender delegate];
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            sender, kPGTSConnectionKey, delegate, kPGTSConnectionDelegateKey, nil];
        NSString* reason = NSLocalizedString (@"Asynchronous connecting not allowed for delegate %p; missing methods", @"Exception reason");
        NSException* e = [NSException exceptionWithName: NSInternalInconsistencyException 
                                                 reason: [NSString stringWithFormat: reason, delegate]
                                               userInfo: userInfo];
        [e raise];
    }
}

/** Database connection */
@implementation PGTSConnection

/** Returns an autoreleased connection object */
+ (PGTSConnection *) connection
{
	return [[[[self class] alloc] init] autorelease];
}

- (id) init
{
    //This might not get called when using the static library
    PGTSInit ();
    
    if ((self = [super init]))
    {
        connection = NULL;
        connectionLock = [[NSLock alloc] init];
        connectionStatus = CONNECTION_BAD;
        messageDelegateAfterConnecting = YES;
        //socket is managed by the worker thread
        cancelRequest = NULL;
        timeout.tv_sec = 15;
        timeout.tv_usec = 0;
        
        workerThreadLock = [[NSLock alloc] init];
        asyncConnectionLock = [[NSLock alloc] init];
        
        postgresNotificationCenter = [[NSNotificationCenter PGTSNotificationCenter] retain];
        notificationCounts = [[NSCountedSet alloc] init];
        notificationAssociations = [[NSMutableDictionary alloc] init];
        
        [self setConnectionDictionary: kPGTSDefaultConnectionDictionary];
        
        resultSetClass = [PGTSResultSet class];
        
        parameterCounts = [[TSObjectTagDictionary alloc] init];
        delegateProcessesNotices = NO;
        overlooksFailedQueries = YES;
        connectsAutomatically = NO;
        reconnectsAutomatically = NO;
        logsQueries = NO;
        failedToSendQuery = NO;
        initialCommands = nil;
        //databaseInfo is set after the connection has been made
        
        exceptionTable = 0;
        [self setDelegate: nil];        

        id messenger = [TSRunloopMessenger runLoopMessengerForCurrentRunLoop];
        mainProxy          = [[messenger target: self withResult: NO]  retain];
        returningMainProxy = [[messenger target: self withResult: YES] retain];
        NSLock* threadStartLock = [[NSLock alloc] init];

        //Wait for the worker thread to start
        [threadStartLock lock];
        [NSThread detachNewThreadSelector: @selector (workerThreadMain:) toTarget: self withObject: threadStartLock];
        [threadStartLock lock];
        [threadStartLock unlock];
        [threadStartLock release];        
    }
	return self;
}

/**
 * Construct a similiar connection object without actually connecting to the database
 */
- (id) disconnectedCopy
{
    PGTSConnection* anObject = [[[self class] alloc] init];
    anObject->timeout = timeout;
    [anObject setConnectionString: connectionString];
    [anObject setDeserializationDictionary: deserializationDictionary];
    anObject->connectsAutomatically = connectsAutomatically;
    anObject->reconnectsAutomatically = reconnectsAutomatically;
    anObject->overlooksFailedQueries = overlooksFailedQueries;
    [anObject setInitialCommands: initialCommands];
    anObject->resultSetClass = resultSetClass;
    [anObject setDelegate: delegate];
    anObject->logsQueries = logsQueries;
    
    return anObject;
}

- (void) dealloc
{
    //FIXME: this method needs a check.
    [self disconnect];
    //Wait for the other thread to end
    [self endWorkerThread];
    
    [connectionLock release];
    
    [workerThreadLock release];
    [asyncConnectionLock release];
    
    [postgresNotificationCenter release];
    [notificationCounts release];
    [notificationAssociations release];
    
    [parameterCounts release];
    [connectionString release];
    [initialCommands release];
    
    NSLog (@"Deallocating db connection: %p", self);
    [super dealloc];
}

/**
 * Connect or reconnect asynchronously
 * The delegate is required to respond to some related messages
 */
//@{
- (BOOL) connectAsync
{
    BOOL rval = NO;
    CheckExceptionTable (self, kPGTSRaiseForConnectAsync, messageDelegateAfterConnecting);
    if (NULL == connection)
    {
        const char* conninfo = [connectionString UTF8String];
        if ((connection = PQconnectStart (conninfo)))
        {
            rval = YES;
            [workerProxy workerPollConnectionResetting: NO];
        }
    }
    return rval;
}

- (BOOL) reconnectAsync
{
    BOOL rval = NO;
    CheckExceptionTable (self, kPGTSRaiseForReconnectAsync, messageDelegateAfterConnecting);
    if (NULL != connection && 1 == PQresetStart (connection))
    {
        rval = YES;
        [workerProxy workerPollConnectionResetting: YES];
    }    
    return rval;
}
//@}

/**
 * Connect or reconnect synchronously
 */
//@{
- (ConnStatusType) connect
{
    BlockWhileConnecting ([self connectAsync]);    
    return connectionStatus;
}

- (ConnStatusType) reconnect
{
    if (CONNECTION_OK != connectionStatus)
        BlockWhileConnecting ([self reconnectAsync]);
    return connectionStatus;
}
//@}

/**
 * End the worker thread
 */
- (void) endWorkerThread
{
    messageDelegateAfterConnecting = NO;
    [asyncConnectionLock lock];
    [asyncConnectionLock unlock];
    shouldContinueThread = NO;
    [workerProxy workerEnd];
    [workerThreadLock lock];
    [workerThreadLock unlock];    
}


/**
 * Disconnect from the database
 */
- (void) disconnect
{
   if (NULL != connection)
   {
       [asyncConnectionLock lock];
       [asyncConnectionLock unlock];
       NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
       [nc postNotificationName: kPGTSWillDisconnectNotification object: self];
       [[PGTSConnectionPool sharedInstance] removeConnection: self];
       
       [connectionLock lock];
       [socket closeFile];
       [socket release];
       socket = nil;
       if (NULL != cancelRequest)
           PQfreeCancel (cancelRequest);
       PQfinish (connection);
       connection = NULL;
       
       [connectionLock unlock];
       [nc postNotificationName: kPGTSDidDisconnectNotification object: self];
   }
}

- (NSNotificationCenter *) postgresNotificationCenter
{
    return postgresNotificationCenter;
}

/**
 * Send a LISTEN query and register an object to receive notifications from this connection
 * \param anObject The observer
 * \param aSelector The method to be called upon notification. It should take one parameter the type of which is NSNotification
 */
- (void) startListening: (id) anObject forNotification: (NSString *) notificationName selector: (SEL) aSelector
{    
    [self startListening: anObject forNotification: notificationName 
                selector: aSelector sendQuery: YES];
}

- (void) startListening: (id) anObject forNotification: (NSString *) notificationName 
               selector: (SEL) aSelector sendQuery: (BOOL) sendQuery
{
    //Keep track of listeners although this should probably be done in the NotificationCenter
    NSValue* objectIdentifier = [NSValue valueWithPointer: anObject];
    NSMutableSet* objectNotifications = [notificationAssociations objectForKey: objectIdentifier];
    if (nil == objectNotifications)
    {
        objectNotifications = [NSMutableSet set];
        [notificationAssociations setObject: objectNotifications forKey: objectIdentifier];
    }
    else if ([objectNotifications containsObject: notificationName])
        return; //We already were listening
    
    [postgresNotificationCenter addObserver: anObject 
                                   selector: aSelector
                                       name: notificationName 
                                     object: self];    
    if (sendQuery && ![notificationCounts containsObject: notificationName])
    {
        [self executeQuery: [NSString stringWithFormat: @"LISTEN \"%@\"", notificationName]];
    }
    
    [objectNotifications addObject: notificationName];
    [notificationCounts addObject: notificationName];
}

/**
 * Remove an object as the observer of notifications with the given name
 * An UNLISTEN query is also sent if the object is the only observer for the given notification
 */
- (void) stopListening: (id) anObject forNotification: (NSString *) notificationName
{
    NSValue* objectIdentifier = [NSValue valueWithPointer: anObject];
    NSMutableSet* objectNotifications = [notificationAssociations objectForKey: objectIdentifier];
    if ([objectNotifications containsObject: notificationName])
    {
        [objectNotifications removeObject: notificationName];
        [notificationCounts removeObject: notificationName];
        if (![notificationCounts containsObject: notificationName])
        {
            [self executeQuery: [@"UNLISTEN " stringByAppendingString: notificationName]];
        }
        
        [postgresNotificationCenter removeObserver: anObject 
                                              name: notificationName 
                                            object: self];
    }
}

/**
 * Remove an object as the observer of any notifications
 */
- (void) stopListening: (id) anObject
{
    NSValue* objectIdentifier = [NSValue valueWithPointer: anObject];
    NSEnumerator* e = [[notificationAssociations objectForKey: objectIdentifier] objectEnumerator];
    NSString* notificationName;
    while ((notificationName = [e nextObject]))
    {
        [notificationCounts removeObject: notificationName];
        if (![notificationCounts containsObject: notificationName])
        {
            [self executeQuery: [@"UNLISTEN " stringByAppendingString: notificationName]];
        }
    }
    [notificationAssociations removeObjectForKey: objectIdentifier];

    [postgresNotificationCenter removeObserver: anObject];
}

@end


/** Miscellaneous accessors */
@implementation PGTSConnection (MiscAccessors)

/** Returns YES if OpenSSL was linked at compile time */
+ (BOOL) hasSSLCapability
{
#ifdef USE_SSL
    return YES;
#else
    return NO;
#endif
}

/** Connection status */
- (ConnStatusType) status
{
    return connectionStatus;
}

/** The connection object from libpq */
- (PGconn *) pgConnection
{
    return connection;
}

/**
 * Connection variables.
 */
//@{
#define SetIf( VALUE, KEY ) if ((VALUE)) [connectionDict setObject: VALUE forKey: KEY];
- (BOOL) setConnectionURL: (NSURL *) url
{
    NSLog (@"url: %@", url);
    BOOL rval = NO;
    if (0 == [@"pgsql" caseInsensitiveCompare: [url scheme]])
    {
        rval = YES;
        NSMutableDictionary* connectionDict = [NSMutableDictionary dictionary];    
        
        NSString* relativePath = [url relativePath];
        if (1 <= [relativePath length])
            SetIf ([relativePath substringFromIndex: 1], kPGTSDatabaseNameKey);

        SetIf ([url host], kPGTSHostKey);
        SetIf ([url user], kPGTSUserNameKey);
        SetIf ([url password], kPGTSPasswordKey);
        SetIf ([url port], kPGTSPortKey);
        [self setConnectionDictionary: connectionDict];
    }
    return rval;
}

/** \sa PGTSConstants.h for keys */
- (void) setConnectionDictionary: (NSDictionary *) userDict
{
    NSMutableDictionary* connectionDict = [[kPGTSDefaultConnectionDictionary mutableCopy] autorelease];
    [connectionDict addEntriesFromDictionary: userDict];
    [self setConnectionString: [connectionDict PGTSConnectionString]];
}

/** Set the connection string directly */
- (void) setConnectionString: (NSString *) aString
{
    if (connectionString != aString)
    {
        [connectionString release];
        connectionString = [aString retain];
    }
}
//@}

/** Return the connection string set using an NSDictionary or NSString */
- (NSString *) connectionString
{
    return connectionString;
}

/**
 * The delegate
 */
//@{
- (id <PGTSConnectionDelegate>) delegate
{
    return delegate;
}

- (void) setDelegate: (id <PGTSConnectionDelegate>) anObject
{    
    delegate = anObject;
    
    delegateProcessesNotices = NO;
    if ([anObject respondsToSelector: kPGTSReceivedNoticeSelector])
        delegateProcessesNotices = YES;
    
    struct exceptionAssociation associations [] =
    {
        //AssociateSelector (kPGTSSentQuerySelector, kPGTSRaiseForCompletelyAsync),
        AssociateSelector (kPGTSFailedToSendQuerySelector, kPGTSRaiseForCompletelyAsync),
        AssociateSelector (kPGTSAcceptCopyingDataSelector, kPGTSRaiseForSendCopyData),
        AssociateSelector (kPGTSReceivedDataSelector, kPGTSRaiseForReceiveCopyData),
        AssociateSelector (kPGTSReceivedResultSetSelector, kPGTSRaiseForAsync),
        //AssociateSelector (kPGTSReceivedErrorSelector, kPGTSRaiseForAsync),
        
        AssociateSelector (kPGTSConnectionFailedSelector, kPGTSRaiseForConnectAsync),
        AssociateSelector (kPGTSConnectionEstablishedSelector, kPGTSRaiseForConnectAsync),
        AssociateSelector (kPGTSConnectionFailedSelector, kPGTSRaiseForReconnectAsync),
        AssociateSelector (kPGTSDidReconnectSelector, kPGTSRaiseForReconnectAsync),

        AssociateSelector (NULL, 0)
    };
    
    for (int i = 0; NULL != associations [i].selector; i++)
    {
        //Cancel only the exceptions the delegate is responsible for
        exceptionTable &= ~associations [i].exceptBit;
    }

    for (int i = 0; NULL != associations [i].selector; i++)
    {
        if (NO == [anObject respondsToSelector: associations [i].selector])
            exceptionTable |= associations [i].exceptBit;
    }    
}
//@}

- (BOOL) overlooksFailedQueries
{
    return overlooksFailedQueries;
}

/**
 * Set the framework to call PGTSConnection:receivedResultSet: instead of PGTSConnection:receivedError:
 */
- (void) setOverlooksFailedQueries: (BOOL) aBool
{
    overlooksFailedQueries = aBool;
}

/**
 * Connect automatically after awakeFromNib
 */
//@{
- (BOOL) connectsAutomatically
{
    return connectsAutomatically;
}

- (void) setConnectsAutomatically: (BOOL) aBool
{
    connectsAutomatically = aBool;
}
//@}

/**
 * Reset connection automatically
 */
//@{
- (BOOL) reconnectsAutomatically
{
    return reconnectsAutomatically;
}

- (void) setReconnectsAutomatically: (BOOL) aBool
{
    reconnectsAutomatically = aBool;
}
//@}

/**
 * Initial commands after making the connecting
 * \sa sendFinishedConnectingMessage:reconnect:
 */
//@{
- (NSString *) initialCommands
{
    return initialCommands;
}

- (void) setInitialCommands: (NSString *) aString
{
    if (aString != initialCommands)
    {
        [initialCommands release];
        initialCommands = [aString retain];
    }
}
//@}

/**
 * Information object related to the connected database
 */
//@{
/** \return the PGTSDatabaseInfo object, or nil if disconnected */
- (PGTSDatabaseInfo *) databaseInfo
{
    return databaseInfo;
}
/** Make a weak reference to the given object */
- (void) setDatabaseInfo: (PGTSDatabaseInfo *) anObject
{
    databaseInfo = anObject;
}
//@}

/**
 * The deserialization dictionary for result sets returned by this connection
 */
//@{
- (NSMutableDictionary *) deserializationDictionary
{
    return deserializationDictionary;
}

- (void) setDeserializationDictionary: (NSMutableDictionary *) aDictionary
{
    if (deserializationDictionary != aDictionary)
    {
        [deserializationDictionary release];
        deserializationDictionary = [aDictionary retain];
    }
}
//@}

/**
 * Connection timeout
 */
//@{
- (struct timeval) timeout
{
    return timeout;
}

- (void) setTimeout: (struct timeval) value
{
    timeout = value;
}
//@}

- (void) setLogsQueries: (BOOL) aBool
{
    logsQueries = aBool;
}

- (BOOL) logsQueries
{
    return logsQueries;
}
@end


/** 
 * Convenience methods for transaction handling
 * \return a BOOL indicating whether the query was successful
 */
@implementation PGTSConnection (TransactionHandling)
- (BOOL) beginTransaction
{
    return ((nil != [self executeQuery: @"BEGIN"]));
}

- (BOOL) commitTransaction
{
    return ((nil != [self executeQuery: @"COMMIT"]));
}

- (BOOL) rollbackTransaction
{
    return ((nil != [self executeQuery: @"ROLLBACK"]));
}

- (BOOL) rollbackToSavepointNamed: (NSString *) aName
{
    return ((nil != [self executeQuery: [NSString stringWithFormat: @"ROLLBACK TO SAVEPOINT %@", aName]]));
}

- (BOOL) savepointNamed: (NSString *) aName
{
    return ((nil != [self executeQuery: [NSString stringWithFormat: @"SAVEPOINT %@", aName]]));
}
@end


/** 
 * Connection status 
 */
@implementation PGTSConnection (StatusMethods)

- (BOOL) connected
{
    return (NULL != connection && CONNECTION_BAD != [self connectionStatus]);
}

- (NSString *) databaseName
{
    return SafeStatusAccessor (&PQdb, connection);
}

- (NSString *) user
{
    return SafeStatusAccessor (&PQuser, connection);
}

- (NSString *) password
{
    return SafeStatusAccessor (&PQpass, connection);
}

- (NSString *) host
{
    return SafeStatusAccessor (&PQhost, connection);
}

- (long) port
{
    long rval = 0;
    char* portString = PQport (connection);
    if (NULL != portString)
        rval = strtol (portString, NULL, 10);
    return rval;
}

- (NSString *) commandLineOptions
{
    return SafeStatusAccessor (&PQoptions, connection);
}

- (ConnStatusType) connectionStatus
{
    return PQstatus (connection);
}

- (PGTransactionStatusType) transactionStatus
{
    return PQtransactionStatus (connection);
}

- (NSString *) statusOfParameter: (NSString *) parameterName
{
    NSString* rval = nil;
    if (nil != parameterName)
    {
        const char* value = PQparameterStatus (connection, 
                                               [parameterName UTF8String]);
        if (NULL != value)
            rval = [NSString stringWithUTF8String: value];
    }
    return rval;
}

- (int) protocolVersion
{
    return PQprotocolVersion (connection);
}

- (int) serverVersion
{
    return PQserverVersion (connection);
}

/**
 * The last error message.
 */
- (NSString *) errorMessage
{
    NSString* rval = nil;
    char* errorMessage = PQerrorMessage (connection);
    if (0 != strlen (errorMessage))
        rval = [NSString stringWithUTF8String: errorMessage];
	return rval;
}

- (int) backendPID
{
	return PQbackendPID (connection);
}

- (SSL *) sslStruct
{
#ifdef USE_SSL
	return PQgetssl (connection);
#else
    return NULL;
#endif
}

@end


/** NSCoding implementation */
@implementation PGTSConnection (NSCoding)

- (id) initWithCoder: (NSCoder *) decoder
{
    if ((self = [super init]))
    {
        unsigned int returnedLength = 0;
        {
            //exceptionTable is set in setDelegate:
            
            connection = NULL;
            connectionLock = [[NSLock alloc] init];
            {
                timeout.tv_sec  = *[decoder decodeBytesForKey: @"timeout.tv_sec"  returnedLength: &returnedLength];
                if (sizeof (timeout.tv_sec) != returnedLength)
                    [[NSException exceptionWithName: NSInternalInconsistencyException reason: nil userInfo: nil] raise];
                timeout.tv_usec = *[decoder decodeBytesForKey: @"timeout.tv_usec" returnedLength: &returnedLength];
                if (sizeof (timeout.tv_usec) != returnedLength)
                    [[NSException exceptionWithName: NSInternalInconsistencyException reason: nil userInfo: nil] raise];
            }
            connectionString = [[decoder decodeObjectForKey: @"connectionString"] retain];
            connectionStatus = CONNECTION_BAD;
            messageDelegateAfterConnecting = YES;
            
            //socket               is set in workerThreadMain:
            asyncConnectionLock  = [[NSLock alloc] init];
            workerThreadLock     = [[NSLock alloc] init];
            //shouldContinueThread is set in workerThreadMain:
            //threadRunning        is set in workerThreadMain:
            {
                id messenger       = [TSRunloopMessenger runLoopMessengerForCurrentRunLoop];            
                mainProxy          = [[messenger target: self withResult: NO]  retain];
                returningMainProxy = [[messenger target: self withResult: YES] retain];
            }
            //workerProxy          is set in workerThreadMain:
            //returningWorkerProxy is set in workerThreadMain:
            
            postgresNotificationCenter = [[NSNotificationCenter PGTSNotificationCenter] retain];
            notificationCounts = [[NSCountedSet alloc] init];
            notificationAssociations = [[NSMutableDictionary alloc] init];

            cancelRequest = NULL;
            //databaseInfo is set after the connection has been made
            parameterCounts = [[TSObjectTagDictionary alloc] init];
            deserializationDictionary = [decoder decodeObjectForKey: @"deserializationDictionary"];
            connectsAutomatically =  [decoder decodeBoolForKey: @"connectsAutomatically"];
            reconnectsAutomatically =  [decoder decodeBoolForKey: @"reconnectsAutomatically"];
            overlooksFailedQueries = [decoder decodeBoolForKey: @"overlooksFailedQueries"];
            delegateProcessesNotices = NO; //sic
            logsQueries = [decoder decodeBoolForKey: @"logQueries"];
            initialCommands = [[decoder decodeObjectForKey: @"initialCommands"] retain];
            {
                resultSetClass = NSClassFromString ([decoder decodeObjectForKey: @"resultSetClass"]);
                if (Nil == resultSetClass)
                    [[NSException exceptionWithName: NSInternalInconsistencyException reason: nil userInfo: nil] raise];
            }
            [self setDelegate: [decoder decodeObjectForKey: @"delegate"]];
        }
                
        {
            //Wait for the worker thread to start
            NSLock* threadStartLock = [[NSLock alloc] init];
            [threadStartLock lock];
            [NSThread detachNewThreadSelector: @selector (workerThreadMain:) toTarget: self withObject: threadStartLock];
            [threadStartLock lock];
            [threadStartLock unlock];
            [threadStartLock release];
            
            [[PGTSConnectionPool sharedInstance] addConnection: self];
        }
            
        if (connectsAutomatically)
            [self connect];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *) encoder
{
    //Operate on a disconnected copy to make reconnecting possible
    PGTSConnection* c = [self disconnectedCopy];
    {
        //exceptionTable is set in setDelegate:
        
        //connection     is reinitialized
        //connectionLock is reinitialized
        {
            [encoder encodeBytes: (const uint8_t *) &c->timeout.tv_sec  length: sizeof (c->timeout.tv_sec)  forKey: @"timeout.tv_sec"];
            [encoder encodeBytes: (const uint8_t *) &c->timeout.tv_usec length: sizeof (c->timeout.tv_usec) forKey: @"timeout.tv_usec"];        
        }
        [encoder encodeObject: c->connectionString forKey: @"connectionString"];
        //connectionStatus is reinitialized
        //messageDelegateAfterConnecting is reinitialized
        
        //socket               is set in workerThreadMain:
        //asyncConnectionLock  is reinitialized
        //workerThreadLock     is reinitialized
        //shouldContinueThread is set in workerThreadMain:
        //threadRunning        is set in workerThreadMain:
        //mainProxy            is reinitialized
        //returningMainProxy   is reinitialized
        //workerProxy          is set in workerThreadMain:
        //returningWorkerProxy is set in workerThreadMain:
        
        //postgresNotificationCenter is reinitialized
        //notificationCounts         is reinitialized
        //notificationAssociations   is reinitialized
        
        //cancelRequest   is reinitialized
        //databaseInfo    is reinitialized
        //parameterCounts is reinitialized
        [encoder encodeObject: c->deserializationDictionary forKey: @"deserializationDictionary"];
        [encoder encodeBool: c->connectsAutomatically forKey: @"connectsAutomatically"];
        [encoder encodeBool: c->reconnectsAutomatically forKey: @"reconnectsAutomatically"];
        [encoder encodeBool: c->overlooksFailedQueries forKey: @"overlooksFailedQueries"];
        //delegateProcessesNotices is reinitialized (sic)
        [encoder encodeBool: c->logsQueries forKey: @"logQueries"];
        [encoder encodeObject: c->initialCommands forKey: @"initialCommands"];
        [encoder encodeObject: NSStringFromClass (c->resultSetClass) forKey: @"resultSetClass"];
        [encoder encodeConditionalObject: c->delegate forKey: @"delegate"];
    }
    [c release];
}


@end
