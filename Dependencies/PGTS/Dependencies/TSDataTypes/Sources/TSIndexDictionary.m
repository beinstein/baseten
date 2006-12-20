//
// TSIndexDictionary.m
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

#import "TSIndexDictionary.h"


static int IndexCmp (const void *a, const void *b)
{
    int rval = 0;
    if (*(int *) a < *(int *) b)
        rval = -1;
    else if (*(int *) a > *(int *) b)
        rval = 1;
    return rval;
}


@implementation TSIndexEnumerator : TSAbstractEnumerator;

- (id) nextObject
{
    id rval = nil;
    NSNextMapEnumeratorPair (&enumerator, NULL, (void *) &rval);
    return rval;
}

- (unsigned int) nextIndex
{
    unsigned int rval = NSNotFound;
    NSNextMapEnumeratorPair (&enumerator, (void *) &rval, NULL);
    return rval;
}

@end


@implementation TSIndexDictionary

- (id) initWithCapacity: (unsigned int) capacity
{
    if ((self = [super init]))
    {
        count = 0;
        map = NSCreateMapTable (NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, capacity);
    }
    return self;
}

- (id) init
{
    return [self initWithCapacity: 0];
}

- (id) objectAtIndex: (unsigned int) anIndex
{
    return NSMapGet (map, (void *) anIndex);
}

- (void) removeObjectAtIndex: (unsigned int) anIndex
{
    if (NULL != NSMapGet (map, (void *) anIndex))
    {
        count--;
        NSMapRemove (map, (void *) anIndex);
    }
}

- (void) setObject: (id) anObject atIndex: (unsigned int) anIndex
{
    if (NULL == NSMapGet (map, (void *) anIndex))
        count++;
    NSMapInsert (map, (void *) anIndex, anObject);
}

- (TSIndexEnumerator *) indexEnumerator
{
    return (TSIndexEnumerator *)[self objectEnumerator];
}

- (NSEnumerator *) objectEnumerator
{
    NSMapEnumerator e = NSEnumerateMapTable (map);
    return [[[TSIndexEnumerator alloc] initWithCollection: self
                                            mapEnumerator: e] autorelease];
}

- (unsigned int *) indexVector
{
    TSIndexEnumerator* e = [self indexEnumerator];
    unsigned int* vector = calloc (count, sizeof (unsigned int));
    for (int i = 0; i < count; i++)
        vector [i] = [e nextIndex];
    return vector;
}

- (unsigned int *) indexVectorSortedByValue
{
    return [self indexVectorSortedByValueUsingFunction: &IndexCmp];
}

- (unsigned int *) indexVectorSortedByValueUsingFunction: (int (*) (const void *, const void *)) compar;
{
    unsigned int* keys = [self indexVector];
    qsort (keys, count, sizeof (unsigned int), compar);
    return keys;
}

- (void) makeObjectsPerformSelector: (SEL) aSelector withObject: (id) anObject
{
    NSEnumerator* e = [self objectEnumerator];
    id currentObject = nil;
    while ((currentObject = [e nextObject]))
        [currentObject performSelector: aSelector withObject: anObject];
}

- (NSArray *) allObjects
{
    return NSAllMapTableValues (map);
}

- (unsigned int) indexOfObject: (id) anObject
{
    TSIndexEnumerator* e = [self indexEnumerator];
    unsigned int currentIndex = 0;
    while (NSNotFound != (currentIndex = [e nextIndex]))
    {
        if ([[self objectAtIndex: currentIndex] isEqual: anObject])
            break;
    }
    return currentIndex;
}
@end
