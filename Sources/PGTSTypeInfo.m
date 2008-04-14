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

#import "PGTSTypeInfo.h"
#import "PGTSResultSet.h"
#import "PGTSFunctions.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"


/** 
 * Data type in a database
 */
@implementation PGTSTypeDescription

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


@implementation PGTSTypeDescription (Queries)

- (NSString *) name
{
    if (nil == name)
    {
        PGTSResultSet* res = [connection executeQuery: @"SELECT typname, n.oid, nspname, typelem, typdelim "
                                                        "FROM pg_type t, pg_namespace n "
                                                        "WHERE t.oid = $1 AND t.typnamespace = n.oid" parameters: PGTSOidAsObject (oid)];
        [res setDeterminesFieldClassesAutomatically: NO];
        [res setClass: [NSString class] forKey: @"typname"];
        [res setClass: [NSNumber class] forKey: @"oid"];
        [res setClass: [NSString class] forKey: @"nspname"];
        [res setClass: [NSNumber class] forKey: @"typelem"];
        [res setClass: [NSString class] forKey: @"typdelim"];

        if (0 < [res count])
        {
            [res advanceRow];
            [self setName:       [res valueForKey: @"typname"]];
            [self setSchemaOid:  [[res valueForKey: @"oid"] PGTSOidValue]];
            [self setSchemaName: [res valueForKey: @"nspname"]];
            [self setElementOid: [[res valueForKey: @"typelem"] unsignedIntValue]];
            [self setDelimiter:  [[res valueForKey: @"typdelim"] characterAtIndex: 0]];
        }
    }
    return name;
}

- (void) setDatabase: (PGTSDatabaseDescription *) aDatabase
{
    database = aDatabase;
}

- (PGTSDatabaseDescription *) database
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