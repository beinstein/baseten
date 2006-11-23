//
// BXAbstractDescription.m
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

#import "BXAbstractDescription.h"


/**
    An abstract superclass for various description classes.
*/
@implementation BXAbstractDescription

- (id) initWithName: (NSString *) aName
{
    if ((self = [super init]))
    {
        NSAssert (nil != aName, nil);
        mName = [aName copy];
    }
    return self;
}

- (void) setName: (NSString *) aName
{
    if (nil == mName) {
        mName = [aName retain];
    }
}


/** Name of the object */
- (NSString *) name
{
    return [[mName retain] autorelease];
}

- (unsigned int) hash
{
    if (0 == mHash)
        mHash = [mName hash];
    return mHash;
}

- (NSComparisonResult) compare: (id) anObject
{
    NSComparisonResult rval = NSOrderedSame;
    if ([anObject isKindOfClass: [self class]])
        rval = [mName compare: [anObject name]];
    return rval;
}

- (NSComparisonResult) caseInsensitiveCompare: (id) anObject
{
    NSComparisonResult rval = NSOrderedSame;
    if ([anObject isKindOfClass: [self class]])
        rval = [mName caseInsensitiveCompare: [anObject name]];
    return rval;
}

- (BOOL) isEqual: (id) anObject
{
    BOOL rval = NO;
    if ([anObject isKindOfClass: [self class]])
    {
        BXAbstractDescription* aDesc = (BXAbstractDescription *) anObject;
        rval = [mName isEqualToString: aDesc->mName];
    }
    else
    {
        rval = [super isEqual: anObject];
    }
    return rval;
}

@end
