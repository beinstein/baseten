//
// PGTSResultRow.m
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
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

#import "PGTSResultRow.h"
#import "PGTSResultSet.h"
#import "PGTSResultRowProtocol.h"


/**
 * Table row as an object.
 * Returned by some KVC methods in PGTSResultSet
 */
@implementation PGTSResultRow

- (id) init
{
    if ((self = [super init]))
    {
        valueCache = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void) PGTSSetRow: (int) row resultSet: (PGTSResultSet *) res
{
    rowNumber = row;
    [self setResult: res];
}

- (void) setResult: (PGTSResultSet *) res
{
    if (result != res)
    {
        [result release];
        result = [res retain];
    }
}

- (void) dealloc
{
    [result release];
    [valueCache release];
    [super dealloc];
}

- (id) valueForKey: (NSString *) aKey
{
    id rval = [valueCache valueForKey: aKey];
    if ([NSNull null] == rval)
        rval = nil;
    else if (nil == rval)
    {
        rval = [result valueForFieldNamed: aKey row: rowNumber];
        if (nil == rval)
            [valueCache setObject: [NSNull null] forKey: aKey];
        else
            [valueCache setObject: rval forKey: aKey];
    }
    
    return rval;
}

@end
