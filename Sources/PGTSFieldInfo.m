//
// PGTSFieldInfo.m
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

#import <PGTS/PGTSFieldInfo.h>
#import <PGTS/PGTSResultSet.h>
#import <PGTS/PGTSConnection.h>
#import <PGTS/PGTSTableInfo.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSDatabaseInfo.h>
#import <PGTS/PGTSAdditions.h>


/** 
 * Table field
 */
@implementation PGTSFieldDescription

- (id) initWithConnection: (PGTSConnection *) aConnection
{
    if ((self = [super initWithConnection: aConnection]))
    {
        index = 0;
        indexInResultSet = NSNotFound;
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ (%p) s: %@ t: %@ f: %@", 
           [self class], self, [table schemaName], [table name], name];
}

- (void) setIndex: (unsigned int) anIndex
{
    index = anIndex;
}

- (unsigned int) indexInResultSet
{
    return indexInResultSet;
}

- (void) setIndexInResultSet: (unsigned int) anIndex
{
    indexInResultSet = anIndex;
}

- (NSString *) name
{
    if (nil == name && index != 0)
    {
		NSString* query = @"SELECT attname, atttypid, attnotnull FROM pg_attribute WHERE attisdropped = false AND attrelid = $1 AND attnum = $2";
        PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject ([table oid]), [NSNumber numberWithUnsignedInt: index]];
        if ([res advanceRow])
        {
            [self setName: [res valueForFieldNamed: @"attname"]];
            typeOid = [[res valueForFieldNamed: @"atttypid"] PGTSOidValue];
			isNotNull = [[res valueForFieldNamed: @"attnotnull"] boolValue];
        }
    }
    return name;
}

- (NSString *) qualifiedName
{
    NSString* rval = nil;
    if (nil == name)
        [self name];
    if (nil != name)
        rval = [NSString stringWithFormat: @"\"%@\"", name];
    
    return rval;
}

- (unsigned int) index
{
    if (index == 0 && nil != name)
    {
		NSString* query = @"SELECT attnumber, atttypid, attnotnull FROM pg_attribute WHERE attisdropped = false AND attrelid = $1 AND attname = $2";
        PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject ([table oid]), name];
        [self setIndex: [[res valueForFieldNamed: @"attnumber"] unsignedIntValue]];
        typeOid = [[res valueForFieldNamed: @"atttypid"] PGTSOidValue];
		isNotNull = [[res valueForFieldNamed: @"attnotnull"] boolValue];
    }
    return index;
}

- (void) setTable: (PGTSTableDescription *) anObject
{
    table = anObject;
}

- (PGTSTableDescription *) table
{
    return table;
}

- (Oid) typeOid
{
    return typeOid;
}

- (PGTSTypeDescription *) type
{
    return [[table database] typeWithOid: typeOid];
}

- (NSComparisonResult) indexCompare: (PGTSFieldDescription *) aField
{
    NSComparisonResult result = NSOrderedAscending;
    unsigned int anIndex = [aField index];
    if (index > anIndex)
        result = NSOrderedDescending;
    else if (index == anIndex)
        result = NSOrderedSame;
    return result;
}

- (BOOL) isNotNull
{
	return isNotNull;
}

@end
