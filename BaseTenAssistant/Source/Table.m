//
// Table.m
// BaseTen Setup
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

#import "Table.h"


@implementation Table

+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

- (id) init
{
    if ((self = [super init]))
    {
        prepared = NO;
    }
    return self;
}

- (BOOL) prepared
{
    return prepared;
}

- (void) setPrepared: (BOOL) flag
{
    [self willChangeValueForKey: @"prepared"];
    prepared = flag;
    [self didChangeValueForKey: @"prepared"];
}

- (NSString *) name
{
    return name; 
}

- (void) setName: (NSString *) aName
{
    if (name != aName) {
        [name release];
        name = [aName retain];
    }
}

- (Schema *) schema
{
    return schema;
}

- (void) setSchema: (Schema *) aSchema
{
    schema = aSchema;
}

- (Oid) oid
{
    return oid;
}

- (void) setOid: (Oid) anOid
{
    oid = anOid;
}

- (BOOL) isView
{
    return isView;
}

- (void) setView: (BOOL) flag
{
    isView = flag;
}

- (NSComparisonResult) compare: (Table *) anObject
{
	NSComparisonResult retval = NSOrderedSame;
	if ([anObject isKindOfClass: [self class]])
		retval = [name compare: anObject->name];
	return retval;
}

@end