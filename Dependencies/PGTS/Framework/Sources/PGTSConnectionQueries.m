//
// PGTSConnectionQueries.m
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

#import <PGTS/PGTSConnection.h>
#import <PGTS/PGTSConstants.h>
#import <PGTS/PGTSConnectionPrivate.h>
#import <PGTS/PGTSConnectionDelegate.h>
#import <PGTS/PGTSResultSetPrivate.h>
#import <PGTS/PGTSAdditions.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSConnectionDelegate.h>
#import <TSDataTypes/TSDataTypes.h>


@class PGTSResultSet;

/** \cond */
static volatile BOOL sendStartedReconnectingMessage = YES;

//If the last argument is the first of the query paramters, then SHOULD_ADD_LAST should be set to YES
#define StdargToNSArray( ARRAY_VAR, COUNT, LAST, SHOULD_ADD_LAST ) \
    { va_list ap; va_start (ap, LAST); ARRAY_VAR = StdargToNSArray2 (ap, COUNT, SHOULD_ADD_LAST, LAST); va_end (ap); }


#define SendQuery( QUERY_MSG ) \
{ \
    BOOL haveXact = NO; \
    switch ([self transactionStatus]) \
    { \
        case PQTRANS_UNKNOWN: \
            failedToSendQuery = YES; \
            break; \
        case PQTRANS_IDLE: \
            haveXact = YES; \
        default: \
            break; \
    } \
    for (int i = 0; i < 2; i++) \
    { \
        if ((QUERY_MSG) != 1 || CONNECTION_BAD != connectionStatus || NO == reconnectsAutomatically) \
            break; \
        if (YES == sendStartedReconnectingMessage) \
        { \
            NS_DURING \
                [self performSelectorOnMainThread: @selector (PGTSConnectionStartedReconnecting) \
                                       withObject: self \
                                    waitUntilDone: NO]; \
            NS_HANDLER \
                sendStartedReconnectingMessage = NO; \
            NS_ENDHANDLER \
        } \
        PQresetStart (connection); \
        [self workerPollConnectionResetting: YES];  \
        if (YES == haveXact) \
            failedToSendQuery = YES; \
    } \
}


static NSArray*
StdargToNSArray2 (va_list arguments, int paramCount, BOOL addLastParam, id lastParam)
{
    NSMutableArray* parameters = [NSMutableArray arrayWithCapacity: paramCount + 1];
    if (addLastParam)
    {
        if (nil == lastParam)
            lastParam = [NSNull null];
        [parameters addObject: lastParam];
        paramCount--;
    }
    for (int i = 0; i < paramCount; i++)
    {
        id argument = va_arg (arguments, id);
        if (nil == argument)
            argument = [NSNull null];
        [parameters addObject: argument];
    }
    return parameters;
}


static BOOL 
CheckExceptionTable (PGTSConnection* sender, unsigned int flags)
{
    BOOL rval = YES;
    if (sender->exceptionTable & flags)
    {
        rval = NO;
        //FIXME: there are some other selectors which cause these exceptions as well (see -setDelegate: in PGTSConnection)
        if (sender->exceptionTable & flags & kPGTSRaiseForCompletelyAsync)
            [sender raiseExceptionForMissingSelector: kPGTSFailedToSendQuerySelector];
        if (sender->exceptionTable & flags & kPGTSRaiseForAsync)
            [sender raiseExceptionForMissingSelector: kPGTSReceivedResultSetSelector];
    }
    return rval;
}

/** \endcond */


/** Query-related methods executed on the main thread */
@implementation PGTSConnection (QueriesMainThread)

/** 
 * Execute the query.
 * Block until the result is available. Multiple queries can be sent but 
 * the result is returned only for the last successful one.
 */
//@{
- (PGTSResultSet *) executeQuery: (NSString *) queryString
{
    return [self resultFromProxy: returningWorkerProxy
                          status: [returningWorkerProxy sendQuery2: queryString messageDelegate: NO]];
}

- (PGTSResultSet *) executeQuery: (NSString *) queryString parameterArray: (NSArray *) parameters
{
    return [self resultFromProxy: returningWorkerProxy
                          status: [returningWorkerProxy sendQuery2: queryString parameterArray: parameters messageDelegate: NO]];
}

- (PGTSResultSet *) executeQuery: (NSString *) queryString parameters: (id) p1, ...
{
    NSArray* parameters = nil;
    StdargToNSArray (parameters, [queryString PGTSParameterCount], p1, YES);
    return [self executeQuery: queryString parameterArray: parameters];
}

- (PGTSResultSet *) executePrepareQuery: (NSString *) queryString name: (NSString *) aName
{
    return [self executePrepareQuery: queryString name: aName parameterTypes: NULL];
}

- (PGTSResultSet *) executePrepareQuery: (NSString *) queryString name: (NSString *) aName parameterTypes: (Oid *) types
{
    int count = [queryString PGTSParameterCount];
    [parameterCounts setTag: count forKey: aName];
    return [self resultFromProxy: returningWorkerProxy status: 
        [returningWorkerProxy prepareQuery2: queryString name: aName parameterCount: count 
                             parameterTypes: types messageDelegate: NO]];
}

- (PGTSResultSet *) executePreparedQuery: (NSString *) aName
{
    return [self executePreparedQuery: aName parameterArray: nil];
}

- (PGTSResultSet *) executePreparedQuery: (NSString *) aName parameters: (id) p1, ...
{
    NSArray* parameters = nil;
    StdargToNSArray (parameters, [parameterCounts tagForKey: aName], p1, YES);
    return [self executePreparedQuery: aName parameterArray: parameters];
}

- (PGTSResultSet *) executePreparedQuery: (NSString *) aName parameterArray: (NSArray *) parameters
{
    NSAssert ([parameters count] == [parameterCounts tagForKey: aName], nil);
    return [self resultFromProxy: returningWorkerProxy status: 
        [returningWorkerProxy sendPreparedQuery2: aName parameterArray: parameters
                                 messageDelegate: NO]];
}

- (PGTSResultSet *) executeCopyData: (NSData *) data
{
    return [self executeCopyData: data packetSize: 32 * 1024];
}

- (PGTSResultSet *) executeCopyData: (NSData *) data packetSize: (int) packetSize
{
    id rval = nil;
    if (1 == [returningWorkerProxy sendCopyData2: data packetSize: packetSize messageWhenDone: NO])
    {
        [returningWorkerProxy pendingResultSets];
        rval = [self resultFromProxy: returningWorkerProxy status: 
            [returningWorkerProxy endCopyAndAccept2: YES errorMessage: nil messageWhenDone: NO]];
    }
    return rval;
}

- (NSData *) executeReceiveCopyData
{
    volatile NSData* data = nil;
    if ([returningWorkerProxy receiveRetainedCopyData2: &data])
    {
        [data autorelease];
        [returningWorkerProxy pendingResultSets];
    }
    return (NSData *) data;
}

//@}

/**
 * Send the query
 * Block only to make sure that the query was successfully dispatched.
 * The delegate is messaged when the result is available.
 */
//@{
- (int) sendQuery: (NSString *) queryString
{
    int rval = -1;
    if (CheckExceptionTable (self, kPGTSRaiseForAsync))
        rval = [self sendResultsToDelegate: [returningWorkerProxy sendQuery2: queryString messageDelegate: NO]];
    return rval;
}

- (int) sendQuery: (NSString *) queryString parameterArray: (NSArray *) parameters
{
    int rval = -1;
    if (CheckExceptionTable (self, kPGTSRaiseForAsync))
        rval = [self sendResultsToDelegate: [returningWorkerProxy sendQuery2: queryString 
                                                              parameterArray: parameters 
                                                             messageDelegate: NO]];
    return rval;
}

- (int) sendQuery: (NSString *) queryString parameters: (id) p1, ...
{
    NSArray* parameters = nil;
    StdargToNSArray (parameters, [queryString PGTSParameterCount], p1, YES);
    return [self sendQuery2: queryString parameterArray: parameters messageDelegate: NO];
}

- (int) prepareQuery: (NSString *) queryString name: (NSString *) aName
{
    return [self prepareQuery: queryString name: aName types: NULL];
}

- (int) prepareQuery: (NSString *) queryString name: (NSString *) aName types: (Oid *) types
{
    int rval = -1;
    if (CheckExceptionTable (self, kPGTSRaiseForAsync))
    {
        int count = [queryString PGTSParameterCount];
        [parameterCounts setTag: count forKey: aName];
        rval = [self sendResultsToDelegate: 
            [returningWorkerProxy prepareQuery2: queryString name: aName 
                                 parameterCount: count parameterTypes: types messageDelegate: NO]];
    }
    return rval;
}

- (int) sendPreparedQuery: (NSString *) aName parameters: (id) p1, ...
{
    NSArray* parameters = nil;
    StdargToNSArray (parameters, [parameterCounts tagForKey: aName], p1, YES);
    return [self sendPreparedQuery: aName parameterArray: parameters];
}

- (int) sendPreparedQuery: (NSString *) aName parameterArray: (NSArray *) parameters
{
    int rval = -1;
    if (CheckExceptionTable (self, kPGTSRaiseForAsync))
    {
        NSAssert ([parameters count] == [parameterCounts tagForKey: aName], nil);
        rval = [self sendResultsToDelegate: 
            [returningWorkerProxy sendPreparedQuery2: aName parameterArray: parameters
                                     messageDelegate: NO]];
    }
    return rval;
}

- (void) sendCopyData: (NSData *) data
{
    [self sendCopyData: data packetSize: 32 * 1024];
}

- (void) sendCopyData: (NSData *) data packetSize: (int) packetSize
{
    if (CheckExceptionTable (self, kPGTSRaiseForSendCopyData))
        [workerProxy sendCopyData2: data packetSize: packetSize messageWhenDone: YES];
}

- (void) receiveCopyData
{
    if (CheckExceptionTable (self, kPGTSRaiseForReceiveCopyData))
        [workerProxy receiveCopyDataAndSendToDelegate];
}
//@}

/** Cancel the current command */
- (void) cancelCommand
{
    int PQcancel(PGcancel *cancel, char *errbuf, int errbufsize);
}

@end


/** Query-related methods executed on the worker thread */
@implementation PGTSConnection (QueriesWorkerThread)
/**
 * Send the query without retrieving the result
 * The caller must retrieve the result afterwards. This will 
 * not be enforced by the framework
 */
//@{
- (int) sendQuery2: (NSString *) queryString messageDelegate: (BOOL) messageDelegate
{
    int rval = 0;
    LogQuery (queryString);
    [connectionLock lock];
    SendQuery (rval = PQsendQuery (connection, [queryString UTF8String]));
    [connectionLock unlock];
    
    if (messageDelegate)
        [mainProxy sendDispatchStatusToDelegate: rval forQuery: queryString];

    return rval;
}

- (int) sendQuery2: (NSString *) queryString parameterArray: (NSArray *) parameters 
   messageDelegate: (BOOL) messageDelegate
{
    int rval = 0;
    int nParams = [parameters count];
    const char** paramValues  = calloc (nParams, sizeof (char *));
    Oid*   paramTypes   = calloc (nParams, sizeof (Oid));
    int*   paramLengths = calloc (nParams, sizeof (int));
    int*   paramFormats = calloc (nParams, sizeof (int));
    
    for (int i = 0; i < nParams; i++)
    {
        id parameter = [parameters objectAtIndex: i];
        int length = 0;
        const char* value = [parameter PGTSParameterLength: &length connection: self];
        
        //paramTypes   [i] = [parameter PGTSParameterType];
        //paramValues  [i] = value;
        //paramLengths [i] = length;
        //paramFormats [i] = (-1 == length ? 0 : 1);
        
		if([parameter isKindOfClass:[NSData class]]) // FIXME! Handle other binary types as well.
		{
			paramTypes   [i] = InvalidOid;
			paramValues  [i] = value;
			paramLengths [i] = length;
			paramFormats [i] = 1;
		}
		else
		{
			paramTypes   [i] = InvalidOid;
			paramValues  [i] = value;
			paramLengths [i] = -1;
			paramFormats [i] = 0;
		}
    }
    
    LogQuery (queryString);
    [connectionLock lock];
    SendQuery (rval = PQsendQueryParams (connection, [queryString UTF8String], nParams, paramTypes,
                                  paramValues, paramLengths, paramFormats, 0));
    [connectionLock unlock];

    if (messageDelegate)
        [mainProxy sendDispatchStatusToDelegate: rval forQuery: queryString];

    free (paramTypes);
    free (paramValues);
    free (paramLengths);
    free (paramFormats);
    
    return rval;
}

- (int) prepareQuery2: (NSString *) queryString name: (NSString *) aName
       parameterCount: (int) count parameterTypes: (Oid *) types messageDelegate: (BOOL) messageDelegate
{
    int rval = 0;
    //FIXME: logging
    [connectionLock lock];
    SendQuery (rval = PQsendPrepare (connection, [aName UTF8String], [queryString UTF8String], count, types));
    [connectionLock unlock];

    if (messageDelegate)
        [mainProxy sendDispatchStatusToDelegate: rval forQuery: queryString];

    return rval;
}

- (int) sendPreparedQuery2: (NSString *) aName parameterArray: (NSArray *) arguments messageDelegate: (BOOL) messageDelegate
{
    int rval = 0;
    int nParams = [arguments count];
    const char** paramValues = calloc (nParams, sizeof (char *));
    int* paramLengths  = calloc (nParams, sizeof (int));
    int* paramFormats  = calloc (nParams, sizeof (int));
    
    
    for (int i = 0; i < nParams; i++)
    {
        id argument = [arguments objectAtIndex: i];
        int length = 0;
        char* value = [argument PGTSParameterLength: &length connection: self];

        paramValues  [i] = value;
        paramLengths [i] = -1;
        paramFormats [i] = 0;
        //paramLengths [i] = length;
        //paramFormats [i] = (0 == length ? 0 : 1);
    }
    
    LogQuery (aName);
    [connectionLock lock];
    SendQuery (rval = PQsendQueryPrepared (connection, [aName UTF8String], nParams, paramValues, 
                                    (const int *) paramLengths, (const int *) paramFormats, 0));
    [connectionLock unlock];
    
    if (messageDelegate)
        [mainProxy sendDispatchStatusToDelegate: rval forQuery: aName];

    free (paramValues);
    free (paramLengths);
    free (paramFormats);
    
    return rval;
}
//@}


/** Methods associated with the COPY command */
//{@

- (int) sendCopyData2: (NSData *) data packetSize: (int) packetSize messageWhenDone: (BOOL) messageWhenDone
{
    unsigned int length = [data length];
    char* buffer = NULL;
    int rval = -1;
    if (length <= packetSize)
    {
        buffer = (char *) [data bytes];
        [connectionLock lock];
        SendQuery (rval = PQputCopyData (connection, buffer, length));
        [connectionLock unlock];
    }
    else
    {
        for (int i = 0; i < length; i += packetSize)
        {
            [connectionLock lock];
            SendQuery (rval = PQputCopyData (connection, buffer, MIN (i, length - i)));
            [connectionLock unlock];
            if (1 != rval) break;
            buffer += packetSize;
        }
    }
    
    if (messageWhenDone)
    {
        if (1 == rval)
        {
            //Ask the delegate, if endCopyAndAccept2:errorMessage: can be called
            [mainProxy succeededToCopyData: data];
        }
        else
        {
            //The delegate gets the erroneous result set the normal way
            [self retrieveResultsAndSendToDelegate];
        }
    }
        
    return rval;
}

/**
 * Finish the COPY command
 * \param accept Accept the copying
 * \param errorMessage Custom error message, may be nil
 * \param messageWhenDone Whether to send the results to the delegate
 */
- (int) endCopyAndAccept2: (BOOL) accept errorMessage: (NSString *) errorMessage messageWhenDone: (BOOL) messageWhenDone
{
    int rval = 0;
    if (NO == accept && nil == errorMessage)
        errorMessage = NSLocalizedString (@"Copy cancelled", @"User abort");
    
    [connectionLock lock];
    SendQuery (rval = PQputCopyEnd (connection, [errorMessage UTF8String]));
    [connectionLock unlock];
    
    if (messageWhenDone)
        [self retrieveResultsAndSendToDelegate];
    return rval;
}

- (void) receiveCopyDataAndSendToDelegate
{
    volatile NSData* receivedData = nil;
    [self receiveRetainedCopyData2: &receivedData];
    [self retrieveResultsAndSendToDelegate];
    if (nil != receivedData)
        [mainProxy succeededToReceiveData: [receivedData autorelease]];
}

- (int) receiveRetainedCopyData2: (volatile NSData **) dataPtr
{
    char* buffer = NULL;
    int result = 0;
    
    [connectionLock lock];
    SendQuery (result = PQgetCopyData (connection, &buffer, 0));
    [connectionLock unlock];
    
    switch (result)
    {
        case -1:
            //FIXME
            //If this is the case, the pending result set should be obtained (elsewhere)
        case -2:
            break;
        default:
            //Buffer is NUL-terminated
            *dataPtr = [[NSData alloc] initWithBytes: buffer length: result - 1];
            break;
    }
    
    if (NULL != buffer)
        PQfreemem (buffer);
    
    return result;
}
//@}

/**
 * Block and retrieve all pending results
 * If no command is active, nil will be returned
 */
- (NSArray *) pendingResultSets
{
    NSMutableArray* rval = [NSMutableArray array];
    PGTSResultSet* result = nil;
    PGresult* res = NULL;
    
    [connectionLock lock];
    while ((res = PQgetResult (connection)))
    {
        PQconsumeInput (connection);
        [self postPGnotifications];
        result = [PGTSResultSet resultWithPGresult: res connection: self];        
        [rval addObject: result];
        ExecStatusType status = [result status];
        if (PGRES_COPY_IN == status || PGRES_COPY_OUT == status)
            break;        
    }
    [connectionLock unlock];
    
    if (0 == [rval count])
        rval = nil;
    
    return rval;
}

/**
 * Retrieve the pending results and send them to the delegate
 */
- (void) retrieveResultsAndSendToDelegate
{
    NSArray* results = [self pendingResultSets];
    TSEnumerate (currentResult, e, [results objectEnumerator])
        [mainProxy sendResultToDelegate: currentResult];
}

@end
