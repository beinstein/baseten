//
// PGTSLockNotifier.m
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

#import <MKCCollections/MKCCollections.h>
#import <PGTS/postgresql/libpq-fe.h>
#import "PGTSIndexInfo.h"
#import "PGTSLockNotifier.h"
#import "PGTSFunctions.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSConstants.h"
#import "PGTSTableInfo.h"
#import "PGTSDatabaseInfo.h"

#import <Log4Cocoa/Log4Cocoa.h>


#ifndef PGTS_SCHEMA_NAME
#define PGTS_SCHEMA_NAME "PGTS"
#endif

//FIXME: use prepared satements when table names don't change


@implementation PGTSLockNotifier

- (id) init
{
    if ((self = [super init]))
    {
        lockFunctionNames = [[NSMutableDictionary alloc] init];
        lockTableNames = [[NSMutableDictionary alloc] init];
        lastClearCheck = [[NSDate alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [lockFunctionNames release];
    [lockTableNames release];
    [lastClearCheck release];
    [super dealloc];
}

- (void) setLastClearCheck: (NSDate *) date;
{
    if (lastClearCheck != date && NSOrderedAscending == [lastClearCheck compare: date])
    {
        [lastClearCheck release];
        lastClearCheck = [date retain];
    }
}

- (NSArray *) locksForTable: (PGTSTableInfo *) table whereClause: (NSString *) whereClause
{
    return [self locksForTable: table fromItems: nil whereClause: whereClause parameters: nil];
}

- (NSArray *) locksForTable: (PGTSTableInfo *) table fromItems: (NSArray *) fromItems 
                whereClause: (NSString *) whereClause parameters: (NSArray *) parameters
{
    log4AssertValueReturn (nil != connection, nil, @"Expected to have a connection.");

    NSArray* rval = nil;    
    NSString* lockTableName = [notificationNames objectAtIndex: [table oid]];

    if (nil != lockTableName)
    {
        NSString* fromString = @"";
        if (nil != fromItems && 0 < [fromItems count])
            fromString = [@", " stringByAppendingString: [fromItems componentsJoinedByString: @", "]];
        
        PGTSResultSet* res = [connection executeQuery: @"SELECT " PGTS_SCHEMA_NAME ".LockTableCleanup ()"];
        if ([res querySucceeded])
        {
            NSString* query = [NSString stringWithFormat: 
                @"SELECT l.* FROM %@ l %@ NATURAL INNER JOIN %@ WHERE (%@) AND " PGTS_SCHEMA_NAME "_lock_cleared = false", 
                lockTableName, fromString, [table qualifiedName], whereClause];
            res = [connection executeQuery: query parameterArray: parameters];
            if ([res querySucceeded])
                rval = [res resultAsArray];
        }
    }
    return rval;
}

- (NSArray *) sentNotifications
{
    if (nil == sentNotifications)
        sentNotifications = [[NSArray alloc] initWithObjects: 
            kPGTSLockedForUpdate, 
            kPGTSLockedForDelete, 
            kPGTSUnlockedRowsNotification,
            nil];
    return sentNotifications;
}

- (void) removeObserverForTable: (PGTSTableInfo *) table 
			   notificationName: (NSString *) notificationName
{
    [super removeObserverForTable: table notificationName: notificationName];
    if (0 == [observedTables count])
    {
		log4AssertVoidReturn (nil != connection, @"Expected to have a connection.");
        [connection stopListening: self forNotification: @"\"" PGTS_SCHEMA_NAME ".ClearedLocks\""];
    }
}

- (BOOL) observeTable: (PGTSTableInfo *) tableInfo selector: (SEL) aSelector
	 notificationName: (NSString *) notificationName
{
    BOOL zeroCount = ([observedTables count] == 0);
    BOOL rval = [self observeTable: tableInfo selector: aSelector notificationName: notificationName 
				 notificationQuery: @"SELECT " PGTS_SCHEMA_NAME ".ObserveLocks ($1) AS nname"];
    if (YES == rval && YES == zeroCount)
    {
		log4AssertValueReturn (nil != connection, nil, @"Expected to have a connection.");
        //Clock synchronization
        if (nil == [self lastCheckForTable: notificationName])
        {
            PGTSResultSet* res = [connection executeQuery: 
                                    @"SELECT timeofday ()::TIMESTAMP (3) WITHOUT TIME ZONE"];
            [res advanceRow];
            [self setLastCheck: [res valueForKey: @"timeofday"] forTable: [notificationNames objectAtIndex: [tableInfo oid]]];
        }        
        [connection startListening: self forNotification: @"" PGTS_SCHEMA_NAME ".ClearedLocks"
                                      selector: @selector (handleClearNotification:)];
    }
    return rval;
}

- (void) handleClearNotification: (NSNotification *) notification
{
    log4AssertVoidReturn (nil != connection, @"Expected to have a connection.");

    PGTSResultSet* releasedRows = nil;
        
    if (NO == [connection beginTransaction]) goto error;
    
    //Which tables have pending locks?
    NSString* query = @"SELECT " PGTS_SCHEMA_NAME "_lock_relid, max (" PGTS_SCHEMA_NAME "_lock_timestamp) AS last_date "
        " FROM " PGTS_SCHEMA_NAME ".Lock "
        " WHERE " PGTS_SCHEMA_NAME "_lock_cleared = true "
        " AND " PGTS_SCHEMA_NAME "_lock_timestamp > $1 " 
        " AND " PGTS_SCHEMA_NAME "_lock_backend_pid != $2 "
        " AND " PGTS_SCHEMA_NAME "_lock_relid = ANY ($3) "
        " GROUP BY " PGTS_SCHEMA_NAME "_lock_relid ORDER BY last_date ASC ";
    PGTSResultSet* res = [connection executeQuery: query parameters: 
        lastClearCheck,
        [NSNumber numberWithInt: [connection backendPID]], 
        [[observedTables allObjects] valueForKey: @"oid"]];
    if (NO == [res querySucceeded]) goto error;
    
    //Iterate the tables and send notifications
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    NSDictionary* baseUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        connection, kPGTSConnectionKey,
        nil];
    while ([res advanceRow])
    {
        //Check for locks for each table
        NSNumber* relid = [res valueForKey: @"" PGTS_SCHEMA_NAME "_lock_relid"];
        PGTSTableInfo* table = [[connection databaseInfo] tableInfoForTableWithOid: [relid PGTSOidValue]];
        NSArray* pkeyfnames = [[[[table primaryKey] fields] allObjects] valueForKey: @"name"];
        NSString* query = [NSString stringWithFormat: 
            @"SELECT DISTINCT ON (\"%@\") l.* "
            " FROM %@ l NATURAL INNER JOIN %@ "
            " WHERE " PGTS_SCHEMA_NAME "_lock_cleared = true "
            " AND " PGTS_SCHEMA_NAME "_lock_backend_pid != $1 "
            " AND " PGTS_SCHEMA_NAME "_lock_timestamp > $2 ", 
            [pkeyfnames componentsJoinedByString: @"\", \""],
            [self lockTableNameForTable: table], [table qualifiedName]];
        releasedRows = [connection executeQuery: query parameters: relid, lastClearCheck];
        
        if (NO == [releasedRows querySucceeded]) goto error;
        
        //Post the notification
        NSMutableDictionary* userInfo = [baseUserInfo mutableCopy];
        [userInfo setObject: [releasedRows resultAsArray] forKey: kPGTSRowsKey];
        [userInfo setObject: connection forKey: kPGTSConnectionKey];
        [nc postNotificationName: kPGTSUnlockedRowsNotification object: self userInfo: [userInfo autorelease]];
    }
    if (0 < [res countOfRows])
        [self setLastClearCheck: [res valueForKey: @"last_date"]];
        
    if (NO == [connection commitTransaction]) goto error;
    
    return;
error:
    //FIXME: a real exception
    [[NSException exceptionWithName: @"" reason: nil userInfo: nil] raise];
}


- (NSString *) lockFunctionNameForTable: (PGTSTableInfo *) table
{
    NSString* rval = [lockFunctionNames objectForKey: table];
    if (nil == rval)
    {
        //FIXME: does the function return a suitable name?
		log4AssertValueReturn (nil != connection, nil, @"Expected to have a connection.");
        PGTSResultSet* res = [connection executeQuery: @"SELECT " PGTS_SCHEMA_NAME ".LockNotifyFunctionName ($1::OID) AS fname" 
                                           parameters: PGTSOidAsObject ([table oid])];
        [res advanceRow];
        rval = [res valueForFieldNamed: @"fname"];
        [lockFunctionNames setObject: rval forKey: table];
    }
    return rval;
}

- (NSString *) lockTableNameForTable: (PGTSTableInfo *) table
{
    NSString* rval = [lockTableNames objectForKey: table];
    if (nil == rval)
    {
        //FIXME: does the function return a suitable name?
		log4AssertValueReturn (nil != connection, nil, @"Expected to have a connection.");
        PGTSResultSet* res = [connection executeQuery: @"SELECT " PGTS_SCHEMA_NAME ".LockTableName ($1::OID) AS tname" 
                                           parameters: PGTSOidAsObject ([table oid])];
        [res advanceRow];
        rval = [res valueForFieldNamed: @"tname"];
        [lockTableNames setObject: rval forKey: table];
    }
    return rval;
}

- (void) handleNotification: (NSNotification *) notification
{
    log4AssertVoidReturn (nil != connection, @"Expected to have a connection.");
    NSDictionary* userInfo = [notification userInfo];
    NSNumber* backendPID = [NSNumber numberWithInt: [connection backendPID]];
    if (observesSelfGenerated || NO == [[userInfo objectForKey: kPGTSBackendPIDKey] isEqualToNumber: backendPID])
    {
        NSString* lockTableName = [notification name];        
        NSString* addition = @"";
        if (NO == observesSelfGenerated)
            addition = @"AND " PGTS_SCHEMA_NAME "_lock_backend_pid != $2";
        NSString* query = [NSString stringWithFormat: 
            @"SELECT * FROM %@ WHERE " PGTS_SCHEMA_NAME "_lock_cleared = false AND " PGTS_SCHEMA_NAME "_lock_timestamp > $1::timestamp %@ "
            " ORDER BY " PGTS_SCHEMA_NAME "_lock_relid ASC, " PGTS_SCHEMA_NAME "_lock_timestamp ASC", 
            lockTableName, addition];
        PGTSResultSet* res = [connection executeQuery: query parameters: [self lastCheckForTable: lockTableName], backendPID];
        
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        NSMutableDictionary* baseUserInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
            connection, kPGTSConnectionKey,
            backendPID, kPGTSBackendPIDKey,
            nil];
        
        //Combine the notifications so that if there are more than one 
        //for one table, send only one
        //First we need one row
        if ([res advanceRow])
        {
            NSDictionary* row = [res currentRowAsDictionary];
            unichar queryType = [[row valueForKey: @"" PGTS_SCHEMA_NAME "_lock_query_type"] characterAtIndex: 0];
            unichar lastType = '\0';
            Oid tableOid = [[row valueForKey: @"" PGTS_SCHEMA_NAME "_lock_relid"] PGTSOidValue];
            Oid lastOid = InvalidOid;
            do
            {        
                NSMutableArray* rows = [NSMutableArray array];            
                NSString* notificationName = 
                    PGTSLockOperation ([[row valueForKey: @"" PGTS_SCHEMA_NAME "_lock_query_type"] characterAtIndex: 0]);
                
                //Iterate the rows until the type or the table changes
                //This will be done at least once to add the current row to the array
                do
                {
                    [rows addObject: row];
                    if ([res isAtEnd])
                        break;
                    else
                    {
                        //This is the only place where we advance
                        [res advanceRow];
                        row = [res currentRowAsDictionary];
                        lastType = queryType;
                        queryType = [[row valueForKey: @"" PGTS_SCHEMA_NAME "_lock_query_type"] characterAtIndex: 0];
                        lastOid = tableOid;
                        tableOid = [[row valueForKey: @"" PGTS_SCHEMA_NAME "_lock_relid"] PGTSOidValue];
                    }
                }
                while (lastType == queryType && lastOid == tableOid);
                
                //Send the notification
                NSMutableDictionary* userInfo = [baseUserInfo mutableCopy];
                [userInfo setObject: rows forKey: kPGTSRowsKey];
                [nc postNotificationName: notificationName object: self userInfo: [userInfo autorelease]];
            }
            while (NO == [res isAtEnd]);
            [self setLastCheck: [res valueForFieldNamed: @"" PGTS_SCHEMA_NAME "_lock_timestamp"] forTable: lockTableName];
        }
    }
}

@end
