//
// PGTSAbstractClassInfo.m
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

#import <PGTS/PGTSAbstractClassInfo.h>
#import <PGTS/PGTSResultSet.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSConnection.h>
#import <PGTS/PGTSAdditions.h>

/** 
 * Abstract base class for database class objects
 */
@implementation PGTSAbstractClassInfo

- (id) initWithConnection: (PGTSConnection *) aConn
{
    if ((self = [super initWithConnection: aConn]))
    {
        oid = InvalidOid;
        schemaOid = InvalidOid;
    }
    return self;
}

- (void) dealloc
{
    [schemaName release];
    [super dealloc];
}

- (Oid) oid
{
    return oid;
}

- (void) setOid: (Oid) anOid
{
    oid = anOid;
}

- (Oid) schemaOid
{
    return schemaOid;
}

- (void) setSchemaOid: (Oid) anOid
{
    schemaOid = anOid;
}

- (void) setSchemaName: (NSString *) aString
{
    if (schemaName != aString)
    {
        [schemaName release];
        schemaName = [aString retain];
    }
}

@end


@implementation PGTSAbstractClassInfo (Queries)

- (Oid) schemaOid
{
    //Perform the query and check again
    if (InvalidOid == schemaOid)
        [self name];
    return schemaOid;
}

- (NSString *) schemaName
{
    if (nil == schemaName)
        [self name];
    return schemaName;
}

- (NSString *) name
{
    if (nil == name)
    {
        PGTSResultSet* res = [connection executeQuery: @"SELECT relname, n.oid, nspname FROM pg_class c, pg_namespace n "
                                                        "WHERE c.oid = $1 AND c.relnamespace = n.oid"
                                           parameters: PGTSOidAsObject (oid)];
        if (0 < [res numberOfRowsAffected])
        {
            [res advanceRow];
            [self setName:  [res valueForFieldNamed: @"relname"]];
            [self setSchemaName: [res valueForFieldNamed: @"nspname"]];
            [self setSchemaOid: [[res valueForFieldNamed: @"oid"] PGTSOidValue]];
        }
    }
    return name;
}

- (NSString *) qualifiedName
{
    if (nil == name)
        [self name];
    return [NSString stringWithFormat: @"\"%@\".\"%@\"", schemaName, name];
}

@end