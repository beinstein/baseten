//
// PGTSFunctions.m
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

#import <libgen.h>
#import <Foundation/Foundation.h>
#import "postgresql/libpq-fe.h"
#import "PGTSFunctions.h"
#import "PGTSConstants.h"
#import "PGTSConnectionDelegate.h"
#import "PGTSConnectionPrivate.h"


void 
PGTSLog2 (char* path, int line, NSString* format, ...)
{
    va_list ap;
    va_start (ap, format);
    
    fprintf (stderr, "PGTS (%s:%d): ", basename (path), line);
    NSLogv (format, ap);
    
    va_end (ap);    
}


void 
PGTSInit ()
{   
    static int tooLate = 0;
    if (0 == tooLate)
    {
        tooLate = 1;
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        
        kPGTSSentQuerySelector                  = @selector (PGTSConnection:sentQuery:);
        kPGTSFailedToSendQuerySelector          = @selector (PGTSConnection:failedToSendQuery:);
        kPGTSAcceptCopyingDataSelector          = @selector (PGTSConnection:acceptCopyingData:errorMessage:);
        kPGTSReceivedDataSelector               = @selector (PGTSConnection:receivedData:);
        kPGTSReceivedResultSetSelector          = @selector (PGTSConnection:receivedResultSet:);
        kPGTSReceivedErrorSelector              = @selector (PGTSConnection:receivedError:);
        kPGTSReceivedNoticeSelector             = @selector (PGTSConnection:receivedNotice:);
        
        kPGTSConnectionFailedSelector           = @selector (PGTSConnectionFailed:);
        kPGTSConnectionEstablishedSelector      = @selector (PGTSConnectionEstablished:);
        kPGTSStartedReconnectingSelector        = @selector (PGTSConnectionStartedReconnecting:);
        kPGTSDidReconnectSelector               = @selector (PGTSConnectionDidReconnect:);
        
        {
            NSMutableArray* keys = [NSMutableArray array];
            kPGTSDefaultConnectionDictionary = [[NSMutableDictionary alloc] init];
            
            PQconninfoOption *option = PQconndefaults ();
            char* keyword = NULL;
            while ((keyword = option->keyword))
            {
                NSString* key = [NSString stringWithUTF8String: keyword];
                [keys addObject: key];
                char* value = option->val;
                if (NULL == value)
                    value = getenv ([key UTF8String]);
                if (NULL == value)
                    value = option->compiled;
                if (NULL != value)
                {
                    [(NSMutableDictionary *) kPGTSDefaultConnectionDictionary setObject: 
                                      [NSString stringWithUTF8String: value] forKey: key];
                }
                option++;
            }
            kPGTSConnectionDictionaryKeys = [keys copy];            
        }
        [pool release];
    }
}

void 
PGTSNoticeProcessor (void* connection, const char* message)
{
    if (NULL != message)
    {
        [(PGTSConnection *) connection performSelectorOnMainThread: @selector (handleNotice:) 
                                                        withObject: [NSString stringWithUTF8String: message] 
                                                     waitUntilDone: NO];
    }
}

/**
 * Return the value as an object
 * \sa PGTSOidValue
 */
id 
PGTSOidAsObject (Oid o)
{
    //Methods inherited from NSValue seem to return an NSValue instead of an NSNumber
    return [NSNumber numberWithUnsignedInt: o];
}


NSString* 
PGTSModificationName (unichar type)
{
    NSString* modificationName = nil;
    switch (type)
    {
        case 'I':
            modificationName = kPGTSInsertModification;
            break;
        case 'U':
            modificationName = kPGTSUpdateModification;
            break;
        case 'D':
            modificationName = kPGTSDeleteModification;
            break;
        default:
            break;
    }
    return modificationName;
}


NSString*
PGTSLockOperation (unichar type)
{
    NSString* lockOperation = nil;
    switch (type)
    {
        case 'U':
            lockOperation = kPGTSLockedForUpdate;
            break;
        case 'D':
            lockOperation = kPGTSLockedForDelete;
            break;
        default:
            break;
    }
    return lockOperation;
}
