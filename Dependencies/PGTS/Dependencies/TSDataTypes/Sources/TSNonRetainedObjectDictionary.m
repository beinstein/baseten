//
// TSNonRetainedObjectDictionary.m
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

#import "TSNonRetainedObjectDictionary.h"


@implementation TSNonRetainedObjectDictionaryEnumerator

- (id) initWithCollection: (id) aDict 
            mapEnumerator: (NSMapEnumerator) anEnumerator
{
    if ((self = [super initWithCollection: aDict mapEnumerator: anEnumerator]))
        enumeratesKeys = NO;
    return self;
}

- (void) setEnumeratesKeys: (BOOL) aBool
{
    enumeratesKeys = aBool;
}

- (NSArray *) allObjects
{
    NSMutableArray* rval = [NSMutableArray array];
    id value = nil;
    while ((value = [self nextObject]))
        [rval addObject: value];
    return rval;
}

- (id) nextObject
{
    id rval = nil;

    if (YES == enumeratesKeys)
        NSNextMapEnumeratorPair (&enumerator, (void *) &rval, NULL);
    else
        NSNextMapEnumeratorPair (&enumerator, NULL, (void *) &rval);

    return rval;
}

@end


@implementation TSNonRetainedObjectDictionary

- (id) initWithCapacity: (unsigned int) capacity
{
    if ((self = [super init]))
    {
        count = 0;
        map = NSCreateMapTable (NSObjectMapKeyCallBacks, NSNonRetainedObjectMapValueCallBacks, capacity);
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
    id rval = [self objectEnumerator];
    [rval setEnumeratesKeys: YES];
    return rval;
}

- (NSEnumerator *) objectEnumerator
{
    NSMapEnumerator e = NSEnumerateMapTable (map);
    NSEnumerator* rval =  [[[TSNonRetainedObjectDictionaryEnumerator alloc] initWithCollection: self 
                                                                                 mapEnumerator: e] autorelease];
    return (TSNonRetainedObjectDictionaryEnumerator *) rval;
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

- (NSArray *) objectsForKeys: (NSArray *) keys notFoundMarker: (id) anObject
{
    NSMutableArray* rval = [NSMutableArray array];
    NSEnumerator* e = [keys objectEnumerator];
    id currentKey = nil;
    while ((currentKey = [e nextObject]))
    {
        id currentValue = [self objectForKey: currentKey];
        if (nil != currentValue)
            [rval addObject: currentValue];
        else
            [rval addObject: anObject];
    }
    return rval;
}
@end
