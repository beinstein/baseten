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

#import "TSObjectTagDictionary.h"
#import <assert.h>


static int TagCmp (const void *a, const void *b)
{
    int rval = 0;
    if (*(int *) a < *(int *) b)
        rval = -1;
    else if (*(int *) a > *(int *) b)
        rval = 1;
    return rval;
}


@implementation TSObjectTagEnumerator

- (id) nextObject
{
    id rval = nil;
    NSNextMapEnumeratorPair (&enumerator, (void *) &rval, NULL);
    return rval;
}

- (unsigned int) nextTag
{
    unsigned int rval = NSNotFound;
    NSNextMapEnumeratorPair (&enumerator, NULL, (void *) &rval);
    return rval;
}

@end


@implementation TSObjectTagDictionary

+ (id) dictionaryWithCapacity: (unsigned int) capacity
{
    return [[[self class] alloc] initWithCapacity: capacity];
}

- (id) initWithCapacity: (unsigned int) capacity
{
    if ((self = [super init]))
    {
        count = 0;
        map = NSCreateMapTable (NSObjectMapKeyCallBacks, NSIntMapValueCallBacks, capacity);
    }
    return self;
}

- (id) init
{
    return [self initWithCapacity: 0];
}

- (unsigned int) tagForKey: (id) anObject;
{
    unsigned int rval = NSNotFound;
    if (NO == NSMapMember (map, anObject, NULL, (void **) &rval))
        assert (NSNotFound == rval);
    return rval;
}

- (void) removeTagForKey: (id) anObject
{
    if (NULL != NSMapGet (map, anObject))
    {
        count--;
        NSMapRemove (map, anObject);
    }
}

- (void) setTag: (unsigned int) aTag forKey: (id) anObject
{
    if (NULL == NSMapGet (map, anObject))
        count++;
    NSMapInsert (map, anObject, (void *) aTag);
}

- (NSEnumerator *) keyEnumerator
{
    return [self tagEnumerator];
}

- (TSObjectTagEnumerator *) tagEnumerator
{
    NSMapEnumerator e = NSEnumerateMapTable (map);
    return [[[TSObjectTagEnumerator alloc] initWithCollection: self mapEnumerator: e] autorelease];
}

- (NSArray *) allKeys
{
    return NSAllMapTableKeys (map);
}

- (unsigned int *) tagVector
{
    TSObjectTagEnumerator* e = [self tagEnumerator];
    unsigned int* vector = calloc (count, sizeof (unsigned int));
    for (unsigned int i = 0; i < count; i++)
        vector [i] = [e nextTag];
    return vector;
}

- (unsigned int *) tagVectorSortedByValue
{
    return [self tagVectorSortedByValueUsingFunction: &TagCmp];
}

- (unsigned int *) tagVectorSortedByValueUsingFunction: (int (*)(const void *, const void *)) compar;
{
    unsigned int* keys = [self tagVector];
    qsort (keys, count, sizeof (unsigned int), compar);
    return keys;
}

@end
