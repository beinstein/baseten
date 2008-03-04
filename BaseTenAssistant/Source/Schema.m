//
// Schema.m
// BaseTen Setup
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
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
// $Id: Schema.m 241 2008-02-22 16:08:56Z tuukka.norri@karppinen.fi $
//

#import "Schema.h"
#import "Table.h"


@implementation Schema

- (id) init
{
    if ((self = [super init]))
    {
        tables = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [tables makeObjectsPerformSelector: @selector (setSchema:) withObject: nil];
    [tables release];
    [super dealloc];
}

- (void) addTable: (Table *) aTable
{
    [aTable setSchema: self];
    [tables addObject: aTable];
}

- (NSString *) name
{
    return name; 
}

- (void) setName: (NSString *) aSchemaName
{
    if (name != aSchemaName) {
        [name release];
        name = [aSchemaName retain];
    }
}

- (NSComparisonResult) compare: (Schema *) anObject
{
	NSComparisonResult retval = NSOrderedSame;
	if ([anObject isKindOfClass: [self class]])
		retval = [name compare: anObject->name];
	return retval;
}

@end