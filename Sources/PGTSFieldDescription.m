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


@implementation PGTSFieldDescriptionProxy
- (PGTSTypeDescription *) type
{
	return [[self database] typeWithOid: [(PGTSFieldDescription *) mDescription typeOid]];
}
@end


/** 
 * Table field.
 */
@implementation PGTSFieldDescription

- (id) init
{
    if ((self = [super init]))
    {
        mIndex = 0;
        //mIndexInResultSet = NSNotFound;
    }
    return self;
}

#if 0
- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ (%p) s: %@ t: %@ f: %@", 
           [self class], self, [mTable schemaName], [mTable name], mName];
}
#endif

- (void) setIndex: (int) anIndex
{
    mIndex = anIndex;
}

- (NSString *) name
{
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
    return mIndex;
}

- (Oid) typeOid
{
    return mTypeOid;
}

- (PGTSTypeDescription *) type
{
	//This is only supposed to be called via the proxy.
	[[NSException exceptionWithName: NSInternalInconsistencyException reason: @"-[PGTSFieldDescription type] called." userInfo: nil] raise];
	return nil;
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
