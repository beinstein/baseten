//
// PGTSConnectionPool.m
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

#import <PGTS/PGTSConnectionPool.h>
#import <PGTS/PGTSConnectionPoolItem.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSDatabaseInfo.h>


/** \cond */
static void
ConnectionPoolTerminate ()
{
    [[PGTSConnectionPool sharedInstance] terminate];
}
/** \endcond */


@implementation PGTSConnection (PGTSConnectionPoolAdditions)
/**
 * The key used in PGTSConnectionPool.
 * A unique identifier for the database.
 */
- (NSString *) connectionPoolKey
{
    NSString* rval = [[self databaseInfo] connectionPoolKey];
    if (nil == rval)
        rval = [NSString stringWithFormat: @"%@:%@:%ld:%@",
            [self databaseName], [self host], [self port], [self user]];
    return rval;
}
@end


/** 
 * Connection pool.
 * The connection pool retains database information related to opened connections.
 * It releases the information either upon user request or automatically after every connection to the database
 * has been closed.
 */
@implementation PGTSConnectionPool
/**
 * The shared connection pool
 */
+ (id) sharedInstance
{
    static id sharedInstance = nil;
    if (nil == sharedInstance)
    {
        sharedInstance = [[self alloc] init];

        //Manages only the shared instance
        atexit (&ConnectionPoolTerminate);
    }
    
    return sharedInstance;
}

- (id) init
{
    if ((self = [super init]))
    {
        pool = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/**
 * Terminate all the connections the pool knows about
 */
- (void) terminate
{
    //If called from exit, we need an autorelease pool
    NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
    [[pool allValues] makeObjectsPerformSelector: @selector (terminate)];
    [ap release];
}

- (void) dealloc
{
    [self terminate];
    [super dealloc];
}

/**
 * The pool item for the given connection
 */
- (PGTSConnectionPoolItem *) itemForConnection: (PGTSConnection *) connection
{
    return [pool objectForKey: [connection connectionPoolKey]];
}

/**
 * Connection to the given database
 */
- (PGTSConnection *) connectionToDatabase: (PGTSDatabaseInfo *) databaseInfo
{
    return [[pool objectForKey: [databaseInfo connectionPoolKey]] someConnection];
}

/**
 * Discard database information.
 * Discards the information if all connections to the database have been closed
 */
- (void) discardItemWithDatabase: (PGTSDatabaseInfo *) databaseInfo
{
    NSString* key = [databaseInfo connectionPoolKey];
    PGTSConnectionPoolItem* item = [pool objectForKey: key];
    if (0 == [item connectionCount])
        [pool removeObjectForKey: key];
}

/**
 * Discard database information for databases to which the user is not connected
 */
- (void) discardUnusedItems
{
    TSEnumerate (key, e, [pool keyEnumerator])
    {
        PGTSConnectionPoolItem* item = [pool objectForKey: key];
        if ([item connectionCount])
            [pool removeObjectForKey: key];
    }
}

/**
 * Set the pool to automatically discard database information when last connection closes
 */
//@{
- (void) setAutomaticallyDiscardsItems: (BOOL) aBool
{
    automaticallyDiscardsItems = aBool;
}

- (BOOL) automaticallyDiscardsItems
{
    return automaticallyDiscardsItems;
}
//@}

/**
 * Add a connection to the pool
 */
- (void) addConnection: (PGTSConnection *) conn
{
    NSString* key = [conn connectionPoolKey];
    PGTSConnectionPoolItem* item = [pool objectForKey: key];
    if (nil == item)
    {
        item = [[PGTSConnectionPoolItem alloc] init];
        [pool setObject: item  forKey: key];
        [item release];
    }
    [item addConnection: conn];
    
    PGTSDatabaseInfo* info = [item databaseInfo];    
    if (nil == info)
    {
        info = [[PGTSDatabaseInfo alloc] initWithConnection: conn];
        [item setDatabaseInfo: info];
        [info setConnectionPoolKey: key];
        [info release];
    }
    [conn setDatabaseInfo: info];
}

/**
 * Remove a connection from the pool
 */
- (void) removeConnection: (PGTSConnection *) conn
{
    PGTSLog (@"pool removeConnection: %@ (%p)", conn, conn);
    NSString* key = [conn connectionPoolKey];
    PGTSConnectionPoolItem* item = [pool objectForKey: key];
    [item removeConnection: conn];
    if (automaticallyDiscardsItems && 0 == [item connectionCount])
        [pool removeObjectForKey: key];
}

- (unsigned int) databaseCount
{
    return [pool count];
}

- (NSEnumerator *) itemEnumerator
{
    return [pool objectEnumerator];
}

@end
