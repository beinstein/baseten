//
// PGTSDatabaseDescription.m
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

#import "PGTSDatabaseDescription.h"
#import "PGTSTypeDescription.h"
#import "PGTSTableDescription.h"
#import "PGTSResultSet.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSFunctions.h"
#import "PGTSRoleDescription.h"
//FIXME: enable logging.
//#import <Log4Cocoa/Log4Cocoa.h>
#define log4AssertValueReturn(...)
    

/** 
 * Database
 */
@implementation PGTSDatabaseDescription

- (id) addDescriptionFor: (Oid) oidValue class: (Class) c toContainer: (NSMutableDictionary *) aDict
{
    id retval = nil;
    if (InvalidOid != oidValue)
    {
        id oidObject = PGTSOidAsObject (oidValue);
        retval = [aDict objectForKey: oidObject];
        if (! retval)
        {
            retval = [[c alloc] initWithConnection: connection];
            [retval setOid: oidValue];
            [retval setDatabase: self];
            [aDict setObject: retval forKey: oidObject];
            [retval release];
        }
    }
    return retval;
}

- (BOOL) schemaExists: (NSString *) schemaName
{
    BOOL rval = YES;
    if (nil == [schemas objectForKey: schemaName])
    {
        NSString* query = @"SELECT oid FROM pg_namespace WHERE nspname = $1";
        PGTSResultSet* res = [connection executeQuery: query parameters: schemaName];
        log4AssertValueReturn ([res querySucceeded], NO, @"Query failed (%@).", [res errorMessage]);
        if (0 == [res count])
            rval = NO;
        else
        {
            NSMutableDictionary* schema = [NSMutableDictionary dictionary];
            [schemas setObject: schema forKey: schemaName];
        }
    }
    return rval;
}

- (id) initWithConnection: (PGTSConnection *) aConnection
{
    if ((self = [super initWithConnection: aConnection]))
    {
        tables = [[NSMutableDictionary alloc] init];
        types  = [[NSMutableDictionary alloc] init];
        schemas = [[NSMutableDictionary alloc] init];
        roles = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [tables makeObjectsPerformSelector: @selector (setDatabase:) withObject: nil];
    [types  makeObjectsPerformSelector: @selector (setDatabase:) withObject: nil];
    
    [tables release];
    [types release];
    [schemas release];
    [roles release];
    [super dealloc];
}

- (PGTSTableDescription *) tableWithOid: (Oid) anOid
{
    return [self addDescriptionFor: anOid class: [PGTSTableDescription class] toContainer: tables];
}

- (PGTSTypeDescription *) typeWithOid: (Oid) anOid
{
    return [self addDescriptionFor: anOid class: [PGTSTypeDescription class] toContainer: types];
}

- (PGTSTableDescription *) table: (NSString *) tableName inSchema: (NSString *) schemaName
{
    if (nil == schemaName || 0 == [schemaName length])
        schemaName = @"public";
    PGTSTableDescription* rval = [[schemas objectForKey: schemaName] objectForKey: tableName];
    if (nil == rval)
    {
        NSString* queryString = 
        @"SELECT c.oid AS oid, c.relnamespace AS schemaoid, c.relacl, c.relowner, c.relkind, r.rolname "
        " FROM pg_class c, pg_namespace n, pg_roles r "
        " WHERE c.relowner = r.oid AND c.relnamespace = n.oid AND c.relname = $1 AND n.nspname = $2";
        PGTSResultSet* res = [connection executeQuery: queryString parameters: tableName, schemaName];
        if (0 < [res count])
        {
            [res advanceRow];
            rval = [self tableWithOid: [[res valueForKey: @"oid"] PGTSOidValue]];
            [rval setName: tableName];
            [rval setKind: [[res valueForKey: @"relkind"] characterAtIndex: 0]];
            [rval setSchemaOid: [[res valueForKey: @"schemaoid"] PGTSOidValue]];

            PGTSRoleDescription* role = [[connection databaseDescription] roleNamed: [res valueForKey: @"rolname"]
                                                                                oid: [[res valueForKey: @"relowner"] PGTSOidValue]];
            [rval setOwner: role];
            
            [rval setSchemaName: schemaName];
            TSEnumerate (currentACLItem, e, [[res valueForKey: @"relacl"] objectEnumerator])
                [rval addACLItem: currentACLItem];
            [self updateTableCache: rval];
        }
    }
    return rval;
}

- (void) updateTableCache: (PGTSTableDescription *) table
{
    if (nil != table)
    {
        NSString* schemaName = [table schemaName];
        NSMutableDictionary* schema = [schemas objectForKey: schemaName];
        if (! schema)
        {
            schema = [NSMutableDictionary dictionary];
            [schemas setObject: schema forKey: schemaName];
        }
        [schema setObject: table forKey: [table name]];
    }
}

- (PGTSRoleDescription *) roleNamed: (NSString *) aName
{
    return [self roleNamed: aName oid: InvalidOid];
}

- (PGTSRoleDescription *) roleNamed: (NSString *) originalName oid: (Oid) oid
{
    id aName = originalName;
    if (nil == aName)
        aName = [NSNull null];
    
    id rval = [roles objectForKey: aName];
    if (nil == rval)
    {
        if (nil != originalName && InvalidOid == oid)
        {
            NSString* query = @"SELECT oid FROM pg_roles WHERE rolname = $1";
            PGTSResultSet* res = [connection executeQuery: query parameters: aName];
            if (0 < [res count])
            {
                [res advanceRow];
                oid = [[res valueForKey: @"oid"] PGTSOidValue];
            }
        }
        
        rval = [[[PGTSRoleDescription alloc] init] autorelease];
        [rval setOid: oid];
        [rval setName: aName];
        [roles setObject: rval forKey: aName];        
    }
    return rval;
}

@end
