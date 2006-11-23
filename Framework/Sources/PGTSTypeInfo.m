//
// PGTSTypeInfo.m
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

#import <PGTS/PGTSTypeInfo.h>
#import <PGTS/PGTSResultSet.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSConnection.h>
#import <PGTS/PGTSAdditions.h>


/** 
 * Data type in a database
 */
@implementation PGTSTypeInfo

- (id) initWithConnection: (PGTSConnection *) aConnection
{
    if ((self = [super initWithConnection: aConnection]))
    {
        elementOid = InvalidOid;
        elementCount = 0;
        delimiter = '\0';
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ (%p) oid: %u sOid: %u sName: %@ t: %@ eOid: %u d: %c", 
        [self class], self, oid, schemaOid, elementOid, name, schemaName, delimiter];
}

@end


@implementation PGTSTypeInfo (Queries)

- (NSString *) name
{
    if (nil == name)
    {
        PGTSResultSet* res = [connection executeQuery: @"SELECT typname, n.oid, nspname, typelem, typdelim "
                                                        "FROM pg_type t, pg_namespace n "
                                                        "WHERE t.oid = $1 AND t.typnamespace = n.oid" parameters: PGTSOidAsObject (oid)];
        [res setDeterminesFieldClassesAutomatically: NO];
        [res setFieldClassesFromArray: [NSArray arrayWithObjects: [NSString class], [NSNumber class], [NSString class], [NSNumber class], [NSString class], nil]];

        if (0 < [res numberOfRowsAffected])
        {
            [res advanceRow];
            [self setName:       [res valueForFieldNamed: @"typname"]];
            [self setSchemaOid:  [[res valueForFieldNamed: @"oid"] PGTSOidValue]];
            [self setSchemaName: [res valueForFieldNamed: @"nspname"]];
            [self setElementOid: [[res valueForFieldNamed: @"typelem"] unsignedIntValue]];
            [self setDelimiter:  [[res valueForFieldNamed: @"typdelim"] characterAtIndex: 0]];
        }
    }
    return name;
}

- (void) setDatabase: (PGTSDatabaseInfo *) aDatabase
{
    database = aDatabase;
}

- (PGTSDatabaseInfo *) database
{
    return database;
}

- (Oid) elementOid
{
    if (nil == name)
        [self name];
    return elementOid;
}

- (char) delimiter
{
    if (nil == name)
        [self name];
    return delimiter;
}

- (void) setElementOid: (Oid) anOid
{
    if (nil == name)
        [self name];
    elementOid = anOid;
}

- (void) setDelimiter: (char) aChar
{
    if (nil == name)
        [self name];
    delimiter = aChar;
}

@end