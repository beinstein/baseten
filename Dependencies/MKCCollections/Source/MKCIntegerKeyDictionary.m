//
// MKCIntegerKeyDictionary.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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


#import "MKCDictionary.h"
#import "MKCDictionaryEnumerators.h"


#ifdef MAC_OS_X_VERSION_10_5
#define CALLBACKS NSIntegerMapKeyCallBacks
#else
#define CALLBACKS NSIntMapKeyCallBacks
#endif


@implementation MKCIntegerKeyDictionary

- (id) initWithCapacity: (NSUInteger) capacity
{
	return [self initWithMapTable: NSCreateMapTableWithZone (CALLBACKS, NSObjectMapValueCallBacks, capacity, [self zone])];
}

- (id) objectAtIndex: (NSUInteger) anIndex
{
	return NSMapGet (mMapTable, (void *) anIndex);
}

- (void) setObject: (id) anObject atIndex: (NSUInteger) anIndex
{
	NSMapInsert (mMapTable, (void *) anIndex, anObject);
}

- (id) keyEnumerator
{
	return [[[MKCIntegerDictionaryKeyEnumerator allocWithZone: [self zone]] initWithEnumerator: NSEnumerateMapTable (mMapTable)] autorelease];
}

- (id) objectForKey: (id) aKey
{
	return [self objectAtIndex: [aKey unsignedIntValue]];
}
			
@end
