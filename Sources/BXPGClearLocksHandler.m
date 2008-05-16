//
// BXPGClearLocksHandler.m
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
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

#import "BXPGLockHandler.h"


@implementation BXPGClearLocksHandler
+ (NSString *) notificationName
{
	return @"baseten.ClearedLocks";
}

- (void) handleNotification: (PGTSNotification *) notification
{
    log4AssertVoidReturn (nil != connection, @"Expected to have a connection.");
	
	PGTSResultSet* xactRes = nil;
    PGTSResultSet* releasedRows = nil;
	
	xactRes = [connection executeQuery: @"BEGIN"];
	if (! [xactRes querySucceeded]) goto error;
    
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
	
	xactRes = [connection executeQuery: @"COMMIT"];
	if (! [xactRes querySucceeded]) goto error;
    
    return;
error:
    //FIXME: a real exception
    [[NSException exceptionWithName: @"" reason: nil userInfo: nil] raise];	
}
@end

