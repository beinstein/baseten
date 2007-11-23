//
// MKCHashTable.m
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

#import "MKCHashTable.h"


#ifndef MAC_OS_X_VERSION_10_5

#define NSHashTableZeroingWeakMemory ((1 << 0))

@interface NSObject (MKCCollectionCompatibility)
- (id) initWithOptions: (unsigned int) options capacity: (unsigned int) capacity;
@end

#endif


@implementation MKCHashTableEnumerator

- (id) initWithEnumerator: (NSHashEnumerator) anEnumerator
{
    if ((self = [super init]))
    {
        mEnumerator = anEnumerator;
    }
    return self;
}

- (void) dealloc
{
    NSEndHashTableEnumeration (&mEnumerator);
    [super dealloc];
}

- (id) nextObject
{
    return NSNextHashEnumeratorItem (&mEnumerator);
}
@end
	

@implementation MKCHashTable

+ (id) hashTableWithCapacity: (NSUInteger) capacity
{
	return [[self copyHashTableWithCapacity: capacity] autorelease];
}

+ (id) copyHashTableWithCapacity: (NSUInteger) capacity
{
	id retval = nil;
	Class cls = NSClassFromString (@"NSHashTable");
	if (Nil == cls)
		retval = [[self alloc] initWithCapacity: capacity];
	else
		retval = [[cls alloc] initWithOptions: NSHashTableZeroingWeakMemory capacity: capacity];
	return retval;
}

- (id) init
{
    return [self initWithCapacity: 0];
}

- (id) initWithCapacity: (NSUInteger) capacity
{
	return [self initWithHash: NSCreateHashTable (NSNonRetainedObjectHashCallBacks, capacity)];
}

- (id) initWithHash: (NSHashTable *) hash
{
    if ((self = [super init]))
    {
        mHash = hash;
    }
    return self;
}

- (void) dealloc
{
    NSFreeHashTable (mHash);
    [super dealloc];
}

- (NSUInteger) count
{
    return NSCountHashTable (mHash);
}

- (void) addObject: (id) anObject
{
    NSHashInsert (mHash, anObject);
}

- (void) removeObject: (id) anObject
{
    NSHashRemove (mHash, anObject);
}

- (BOOL) containsObject: (id) anObject
{
    return (nil != [self member: anObject]);
}

- (id) member: (id) anObject
{
    return NSHashGet (mHash, anObject);
}

- (id) description
{
    return [NSString stringWithFormat: @"<%@ %@>", [self class], NSAllHashTableObjects (mHash)];
}

- (id) objectEnumerator
{
    return [[[MKCHashTableEnumerator alloc] initWithEnumerator: NSEnumerateHashTable (mHash)] autorelease];
}

- (void) removeAllObjects
{
    NSResetHashTable (mHash);
}

- (NSArray *) allObjects
{
    return NSAllHashTableObjects (mHash);
}

- (id) copyWithZone: (NSZone *) zone
{
	return [[[self class] allocWithZone: zone] initWithHash: NSCopyHashTableWithZone (mHash, zone)];
}

- (id) anyObject
{
	return [[self objectEnumerator] nextObject];
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *) state objects: (id *) stackbuf count: (NSUInteger) len
{
	return [(id) mHash countByEnumeratingWithState: state objects: stackbuf count: len];
}

@end
