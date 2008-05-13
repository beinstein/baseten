//
// PGTSIndexDescription.m
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

#import "PGTSIndexDescription.h"


//FIXME: implement this.
@implementation PGTSIndexDescriptionProxy
- (PGTSTableDescription *) table
{
	[[NSException exceptionWithName: NSInternalInconsistencyException reason: @"-[PGTSIndexDescriptionProxy table:] called." userInfo: nil] raise];
	return nil;
}

- (NSSet *) fields
{
	[[NSException exceptionWithName: NSInternalInconsistencyException reason: @"-[PGTSIndexDescriptionProxy fields:] called." userInfo: nil] raise];
	return nil;
}

@end


/** 
 * Table index
 */
@implementation PGTSIndexDescription

- (id) init
{
    if ((self = [super init]))
    {
        mIsUnique = NO;
        mIsPrimaryKey = NO;
    }
    return self;
}

- (void) dealloc
{
    [mFields release];
    [super dealloc];
}

- (void) setFields: (NSSet *) aSet
{
    if (mFields != aSet)
    {
        [mFields release];
        mFields = [aSet copy];
    }
}

- (NSSet *) fields
{
    return mFields;
}

- (void) setUnique: (BOOL) aBool
{
    mIsUnique = aBool;
}

- (BOOL) isUnique
{
    return mIsUnique;
}

- (void) setPrimaryKey: (BOOL) aBool
{
    mIsPrimaryKey = aBool;
}

- (BOOL) isPrimaryKey
{
    return mIsPrimaryKey;
}

- (void) setTable: (PGTSTableDescription *) anObject
{
    mTable = anObject;
}

- (PGTSTableDescription *) table
{
    return mTable;
}

- (Class) proxyClass
{
	return [PGTSIndexDescriptionProxy class];
}
@end
