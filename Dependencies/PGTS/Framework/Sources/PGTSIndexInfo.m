//
// PGTSIndexInfo.m
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

#import "PGTSIndexInfo.h"


/** 
 * Table index
 */
@implementation PGTSIndexInfo

- (id) initWithConnection: (PGTSConnection *) aConnection
{
    if ((self = [super initWithConnection: aConnection]))
    {
        isUnique = NO;
        isPrimaryKey = NO;
    }
    return self;
}

- (void) dealloc
{
    [fields release];
    [super dealloc];
}

- (void) setFields: (NSSet *) aSet
{
    if (fields != aSet)
    {
        [fields release];
        fields = [aSet copy];
    }
}

- (NSSet *) fields
{
    return fields;
}

- (void) setUnique: (BOOL) aBool
{
    isUnique = aBool;
}

- (BOOL) isUnique
{
    return isUnique;
}

- (void) setPrimaryKey: (BOOL) aBool
{
    isPrimaryKey = aBool;
}

- (BOOL) isPrimaryKey
{
    return isPrimaryKey;
}

- (void) setTable: (PGTSTableInfo *) anObject
{
    table = anObject;
}

- (PGTSTableInfo *) table
{
    return table;
}

@end
