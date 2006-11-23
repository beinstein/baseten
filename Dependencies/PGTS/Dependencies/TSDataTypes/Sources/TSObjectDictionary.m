//
// TSObjectDictionary.m
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

#import "TSObjectDictionary.h"


@implementation TSObjectDictionary

- (id) initWithCapacity: (unsigned int) capacity
{
    if ((self = [super init]))
    {
        count = 0;
        map = NSCreateMapTable (NSObjectMapKeyCallBacks, NSObjectMapValueCallBacks, capacity);
    }
    return self;
}

- (id) init
{
    return [self initWithCapacity: 0];
}

- (id) objectForKey: (id) aKey;
{
    return (id) NSMapGet (map, aKey);
}

- (void) removeObjectForKey: (id) anObject
{
    if (NULL != NSMapGet (map, anObject))
    {
        count--;
        NSMapRemove (map, anObject);
    }
}

- (void) setObject: (id) anObject forKey: (id) aKey
{
    if (NULL == NSMapGet (map, aKey))
        count++;
    NSMapInsert (map, aKey, anObject);
}

- (NSEnumerator *) keyEnumerator
{
    return nil;
}

- (NSEnumerator *) objectEnumerator;
{
    return nil;
}

- (NSArray *) allKeys
{
    return NSAllMapTableKeys (map);
}

- (NSArray *) allObjects
{
    return NSAllMapTableValues (map);
}

- (void) makeObjectsPerformSelector: (SEL) aSelector withObject: (id) anObject
{
    NSEnumerator* e = [self objectEnumerator];
    id currentObject = nil;
    while ((currentObject = [e nextObject]))
        [currentObject performSelector: aSelector withObject: anObject];
}
@end
