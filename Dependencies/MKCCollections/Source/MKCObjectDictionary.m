//
// MKCObjectDictionary.m
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

#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
#define NSPointerFunctionsStrongMemory ((0 << 0))
#define NSPointerFunctionsZeroingWeakMemory ((1 << 0))
typedef NSUInteger NSPointerFunctionsOptions;
#endif


@implementation MKCObjectDictionary

+ (id) copyDictionaryWithCapacity: (NSUInteger) capacity strongKeys: (BOOL) strongKeys strongValues: (BOOL) strongValues
{
	id retval = nil;
	Class cls = NSClassFromString (@"NSMapTable");
	if (Nil == cls)
		retval = [[self alloc] initWithCapacity: capacity strongKeys: strongKeys strongValues: strongValues];
	else
	{
		//Create an NSMapTable instance.
		NSPointerFunctionsOptions keyOptions = (strongKeys ? NSPointerFunctionsStrongMemory : NSPointerFunctionsZeroingWeakMemory);
		NSPointerFunctionsOptions valueOptions = (strongValues ? NSPointerFunctionsStrongMemory : NSPointerFunctionsZeroingWeakMemory);
		retval = [[cls alloc] initWithKeyOptions: keyOptions valueOptions: valueOptions capacity: capacity];
	}
	return retval;	
}

- (id) initWithCapacity: (NSUInteger) capacity strongKeys: (BOOL) strongKeys strongValues: (BOOL) strongValues
{
	NSMapTableKeyCallBacks keyCallBacks = (strongKeys ? NSObjectMapKeyCallBacks : NSNonRetainedObjectMapKeyCallBacks);
	NSMapTableValueCallBacks valueCallBacks = (strongValues ? NSObjectMapValueCallBacks : NSNonRetainedObjectMapValueCallBacks);
	return [self initWithMapTable: NSCreateMapTableWithZone (keyCallBacks, valueCallBacks, capacity, [self zone])];
}

- (void) setObject: (id) anObject forKey: (id) aKey
{
	NSMapInsert (mMapTable, aKey, anObject);
}

- (id) objectForKey: (id) aKey
{
    return (id) NSMapGet (mMapTable, aKey);
}

@end
