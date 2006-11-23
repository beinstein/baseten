//
// TSNonRetainedObjectSet.m
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

#import "TSNonRetainedObjectSet.h"


@implementation TSNonRetainedObjectSetEnumerator
- (id) initWithCollection: (id) aCollection enumerator: (NSHashEnumerator) anEnumerator
{
    if ((self = [super init]))
    {
        enumerator = anEnumerator;
        collection = [aCollection retain];
    }
    return self;
}

- (void) dealloc
{
    NSEndHashTableEnumeration (&enumerator);
    [collection release];
    [super dealloc];
}

- (id) nextObject
{
    return NSNextHashEnumeratorItem (&enumerator);
}
@end


@implementation TSNonRetainedObjectSet
- (id) initWithCapacity: (unsigned int) capacity
{
    if ((self = [super init]))
    {
        hash = NSCreateHashTableWithZone (NSNonRetainedObjectHashCallBacks, capacity, [self zone]);
        count = 0;
    }
    return self;
}

- (id) init
{
    return [self initWithCapacity: count];
}

- (void) dealloc
{
    NSFreeHashTable (hash);
    [super dealloc];
}

- (unsigned int) count
{
    return count;
}

- (void) addObject: (id) anObject
{
    NSHashInsert (hash, anObject);
}


- (void) removeObject: (id) anObject
{
    NSHashRemove (hash, anObject);
}

- (BOOL) containsObject: (id) anObject
{
    return (nil != [self member: anObject]);
}

- (id) member: (id) anObject
{
    return NSHashGet (hash, anObject);
}

- (id) description
{
    return [NSString stringWithFormat: @"<%@ %@>", [self class], NSAllHashTableObjects (hash)];
}

- (id) objectEnumerator
{
    return [[[TSNonRetainedObjectSetEnumerator alloc] initWithCollection: self 
                                                              enumerator: NSEnumerateHashTable (hash)] 
        autorelease];
}

- (void) removeAllObjects
{
    NSResetHashTable (hash);
}

- (NSArray *) allObjects
{
    return NSAllHashTableObjects (hash);
}

@end
