//
// PGTSTypeDescription.m
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

#import "PGTSTypeDescription.h"
#import "PGTSResultSet.h"
#import "PGTSFunctions.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"


/** 
 * Data type in a database
 */
@implementation PGTSTypeDescription

- (id) init
{
    if ((self = [super init]))
    {
        mElementOid = InvalidOid;
        mElementCount = 0;
        mDelimiter = '\0';
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ (%p) oid: %u sOid: %u sName: %@ t: %@ eOid: %u d: %c", 
        [self class], self, mOid, mSchemaOid, mElementOid, mName, mSchemaName, mDelimiter];
}

@end


@implementation PGTSTypeDescription (Queries)

- (NSString *) name
{
    if (nil == mName)
    {
        PGTSResultSet* res = [mConnection executeQuery: @"SELECT typname, n.oid, nspname, typelem, typdelim "
                                                        "FROM pg_type t, pg_namespace n "
                                                        "WHERE t.oid = $1 AND t.typnamespace = n.oid" parameters: PGTSOidAsObject (mOid)];
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
    return mName;
}

- (void) setDatabase: (PGTSDatabaseDescription *) aDatabase
{
    mDatabase = aDatabase;
}

- (PGTSDatabaseDescription *) database
{
    return mDatabase;
}

- (Oid) elementOid
{
    if (nil == mName)
        [self name];
    return mElementOid;
}

- (char) delimiter
{
    if (nil == mName)
        [self name];
    return mDelimiter;
}

- (void) setElementOid: (Oid) anOid
{
    if (nil == mName)
        [self name];
    mElementOid = anOid;
}

- (void) setDelimiter: (char) aChar
{
    if (nil == mName)
        [self name];
    mDelimiter = aChar;
}

@end