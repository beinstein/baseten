//
// PGTSConnectionPoolItem.m
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

#import <PGTS/PGTSConnectionPoolItem.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSConstants.h>
#import <PGTS/PGTSDatabaseInfo.h>


/**
 * Package containing database information and open connections.
 * Used by the connection pool to store database information and connections together.
 */
@implementation PGTSConnectionPoolItem

- (id) init
{
    if ((self = [super init]))
    {
        connections = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [self terminate];
    [connections release];
    [super dealloc];
}

/**
 * Some connection to the database
 */
- (PGTSConnection *) someConnection
{
    return [connections anyObject];
}

/**
 * Information object for the database
 */
//@{
- (PGTSDatabaseInfo *) databaseInfo
{
    return database;
}

- (void) setDatabaseInfo: (PGTSDatabaseInfo *) anObject
{
    if (database != anObject)
    {
        [database release];
        database = [anObject retain];
    }
}
//@}

/**
 * Add a connection to the database
 */
- (void) addConnection: (PGTSConnection *) connection
{
    PGTSLog (@"item: %@ (%p) addConnection: %@ (%p)", self, self, connection, connection);
    [connections addObject: connection];
    NSDictionary* userInfo = [NSDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
    [[NSNotificationCenter defaultCenter] postNotificationName: kPGTSConnectionPoolItemDidAddConnectionNotification
                                                        object: self userInfo: userInfo];
}

/**
 * Remove the given connection from the pool
 */
- (void) removeConnection: (PGTSConnection *) connection
{
    PGTSLog (@"item: %@ (%p) removeConnection: %@ (%p)", self, self, connection, connection);
    [connections removeObject: connection];
    NSDictionary* userInfo = [NSDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
    [[NSNotificationCenter defaultCenter] postNotificationName: kPGTSConnectionPoolItemDidRemoveConnectionNotification
                                                        object: self userInfo: userInfo];
}

/**
 * Number of connections to the database
 */
- (unsigned int) connectionCount
{
    return [connections count];
}

/**
 * Terminate all the connections
 */
- (void) terminate
{
    [connections makeObjectsPerformSelector: @selector (disconnect)];
    [connections removeAllObjects];
}

@end
