//
// PGTSModificationNotifier.m
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
#import <TSDataTypes/TSDataTypes.h>
#import <Log4Cocoa/Log4Cocoa.h>
#import <PGTS/postgresql/libpq-fe.h>
#import "PGTSModificationNotifier.h"
#import "PGTSNotifier.h"
#import "PGTSFunctions.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSConstants.h"
#import "PGTSTableInfo.h"
#import "PGTSDatabaseInfo.h"


#ifndef PGTS_SCHEMA_NAME
#define PGTS_SCHEMA_NAME "PGTS"
#endif


@implementation PGTSModificationNotifier

- (id) init
{
    if ((self = [super init]))
    {
        sendCount = 0;
    }
    return self;
}

//FIXME: this seems quite inelegant. It ought to be a class method.
/**
 * Return the last modification made by the given connection
 */
- (NSDictionary *) lastModificationForTable: (PGTSTableInfo *) table connection: (PGTSConnection *) aConnection
{
    NSMutableDictionary* modificationDict = nil;
    if (nil != aConnection)
    {
        NSString* mTableName = [notificationNames objectAtIndex: [table oid]];
        if (nil != mTableName)
        {
            NSString* query = [NSString stringWithFormat: 
                @"SELECT * FROM %@ WHERE " PGTS_SCHEMA_NAME "_modification_backend_pid = pg_backend_pid () "
                " ORDER BY " PGTS_SCHEMA_NAME "_modification_insert_timestamp DESC LIMIT 1; ", 
                mTableName];
            PGTSResultSet* res = [aConnection executeQuery: query];
            if ([res querySucceeded] && [res advanceRow])
            {
                NSDictionary* row = [res currentRowAsDictionary];
                NSString* modificationName = 
                    PGTSModificationName ([[row valueForKey: @"" PGTS_SCHEMA_NAME "_modification_type"] characterAtIndex: 0]);
                
                modificationDict = [NSDictionary dictionaryWithObjectsAndKeys:
                    row, kPGTSRowKey,
                    modificationName, kPGTSModificationNameKey,
                    nil];
            }
        }
    }
    return modificationDict;
}

- (void) removeNotificationIfNeeded: (PGTSTableInfo *) tableInfo
{
    if (0 == [observedTables countForObject: tableInfo])
    {
        NSAssert (nil != connection, nil);
        [connection executeQuery: @"SELECT " PGTS_SCHEMA_NAME ".StopObservingModifications ($1)" 
                      parameters: PGTSOidAsObject ([tableInfo oid])];
    }
}

- (BOOL) addObserver: (id) anObject selector: (SEL) aSelector table: (PGTSTableInfo *) tableInfo 
    notificationName: (NSString *) notificationName
{
    log4Debug (@"addObserver: %@ name: %@", anObject, notificationName);
    BOOL rval =  [self addObserver: anObject selector: aSelector 
                            table: tableInfo notificationName: notificationName 
                notificationQuery: @"SELECT " PGTS_SCHEMA_NAME ".ObserveModifications ($1) AS nname" ];
    if (YES == rval && nil == lastCheck)
    {
        NSAssert (nil != connection, nil);
        PGTSResultSet* res = [connection executeQuery: 
            @"SELECT " PGTS_SCHEMA_NAME ".ModificationTableCleanup ();"
             "SELECT COALESCE (MAX (" PGTS_SCHEMA_NAME "_modification_timestamp), CURRENT_TIMESTAMP)::TIMESTAMP (3) WITHOUT TIME ZONE AS date "
             " FROM " PGTS_SCHEMA_NAME ".Modification;"];
        [res advanceRow];
        [self setLastCheck: [res valueForKey: @"date"]];
    }
    return rval;
}

/**
 * Return the last modification made by the same connection.
 */
- (NSDictionary *) lastModificationForTable: (PGTSTableInfo *) table
{
    NSAssert (nil != connection, nil);
    return [self lastModificationForTable: table connection: connection];
} 

- (void) handleNotification: (NSNotification *) notification
{
    if ([self shouldHandleNotification: notification])
    {
        NSAssert (nil != connection, nil);
        [self checkInModificationTableNamed: [notification name]];
    }
}

- (void) checkForModificationsInTable: (PGTSTableInfo *) table
{
    [self checkInModificationTableNamed: [notificationNames objectAtIndex: [table oid]]];
}

- (void) checkInModificationTableNamed: (NSString *) modificationTableName
{
    NSNumber* backendPID = [NSNumber numberWithInt: [connection backendPID]];
    
    //When observing self-generated modifications, also the ones that still have NULL values for 
    //pgts_modification_timestamp should be included in the query.
    NSString* addition = @"(true)";
    if (NO == observesSelfGenerated)
        addition = @"" PGTS_SCHEMA_NAME "_modification_backend_pid != $2";
    
    NSString* query = [NSString stringWithFormat: 
        @" SELECT * FROM %@ ($1::timestamp) WHERE %@", modificationTableName, addition];
    PGTSResultSet* res = [connection executeQuery: query parameters: lastCheck, backendPID];
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    NSMutableDictionary* baseUserInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        connection, kPGTSConnectionKey,
        backendPID, kPGTSBackendPIDKey,
        nil];
    
    if ([res advanceRow])
    {
        unichar lastType = '\0';
        NSMutableArray* rows = [NSMutableArray array];
        
        for (unsigned int i = 0, count = [res countOfRows]; i <= count; i++)
        {
            NSDictionary* row = [res currentRowAsDictionary];
            unichar modificationType = [[row valueForKey: @"" PGTS_SCHEMA_NAME "_modification_type"] characterAtIndex: 0];                            
            
            if (('\0' != lastType && modificationType != lastType) || i == count)
            {
                //Send the notification
                NSString* notificationName = PGTSModificationName (lastType);
                NSMutableDictionary* userInfo = [[baseUserInfo mutableCopy] autorelease];
                
                [userInfo setObject: [[rows copy] autorelease] forKey: kPGTSRowsKey];
                [nc postNotificationName: notificationName 
                                  object: self
                                userInfo: userInfo];
                sendCount++;
                [rows removeAllObjects];
            }
            
            [rows addObject: row];
            lastType = modificationType;
            [self setLastCheck: [res valueForKey: @"" PGTS_SCHEMA_NAME "_modification_timestamp"]];
            [res advanceRow];
        }        
    }
}

- (NSArray *) sentNotifications
{
    if (nil == sentNotifications)
        sentNotifications = [[NSArray alloc] initWithObjects: 
            kPGTSInsertModification, kPGTSUpdateModification, kPGTSDeleteModification, nil];
    return sentNotifications;
}
    
@end