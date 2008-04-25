//
// PGTSFieldDescription.m
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

#import <PGTS/PGTSFieldDescription.h>
#import <PGTS/PGTSResultSet.h>
#import <PGTS/PGTSConnection.h>
#import <PGTS/PGTSTableDescription.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSDatabaseDescription.h>
#import <PGTS/PGTSAdditions.h>


/** 
 * Table field
 */
@implementation PGTSFieldDescription

- (id) init
{
    if ((self = [super init]))
    {
        mIndex = 0;
        mIndexInResultSet = NSNotFound;
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ (%p) s: %@ t: %@ f: %@", 
           [self class], self, [mTable schemaName], [mTable name], mName];
}

- (void) setIndex: (int) anIndex
{
    mIndex = anIndex;
}

- (int) indexInResultSet
{
    return mIndexInResultSet;
}

- (void) setIndexInResultSet: (int) anIndex
{
    mIndexInResultSet = anIndex;
}

- (NSString *) name
{
    if (nil == mName && mIndex != 0)
    {
		NSString* query = @"SELECT attname, atttypid, attnotnull FROM pg_attribute WHERE attisdropped = false AND attrelid = $1 AND attnum = $2";
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject ([mTable oid]), [NSNumber numberWithUnsignedInt: mIndex]];
        if ([res advanceRow])
        {
            [self setName: [res valueForKey: @"attname"]];
            mTypeOid = [[res valueForKey: @"atttypid"] PGTSOidValue];
			mIsNotNull = [[res valueForKey: @"attnotnull"] boolValue];
        }
    }
    return mName;
}

- (NSString *) qualifiedName
{
    NSString* rval = nil;
    if (nil == mName)
        [self name];
    if (nil != mName)
        rval = [NSString stringWithFormat: @"\"%@\"", mName];
    
    return rval;
}

- (int) index
{
    if (mIndex == 0 && nil != mName)
    {
		NSString* query = @"SELECT attnumber, atttypid, attnotnull FROM pg_attribute WHERE attisdropped = false AND attrelid = $1 AND attname = $2";
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject ([mTable oid]), mName];
        [self setIndex: [[res valueForKey: @"attnumber"] unsignedIntValue]];
        mTypeOid = [[res valueForKey: @"atttypid"] PGTSOidValue];
		mIsNotNull = [[res valueForKey: @"attnotnull"] boolValue];
    }
    return mIndex;
}

- (void) setTable: (PGTSTableDescription *) anObject
{
    mTable = anObject;
}

- (PGTSTableDescription *) table
{
    return mTable;
}

- (Oid) typeOid
{
    return mTypeOid;
}

- (PGTSTypeDescription *) type
{
    return [[mTable database] typeWithOid: mTypeOid];
}

- (NSComparisonResult) indexCompare: (PGTSFieldDescription *) aField
{
    NSComparisonResult result = NSOrderedAscending;
    unsigned int anIndex = [aField index];
    if (mIndex > anIndex)
        result = NSOrderedDescending;
    else if (mIndex == anIndex)
        result = NSOrderedSame;
    return result;
}

- (BOOL) isNotNull
{
	return mIsNotNull;
}

- (Class) proxyClass
{
	return [PGTSFieldDescriptionProxy class];
}

- (void) setTypeOid: (Oid) anOid
{
	mTypeOid = anOid;
}

- (void) setNotNull: (BOOL) aBool
{
	mIsNotNull = aBool;
}
@end
