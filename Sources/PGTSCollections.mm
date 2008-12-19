//
// PGTSCollections.m
// BaseTen
//
// Copyright (C) 2008 Marko Karppinen & Co. LLC.
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

#import "PGTSCollections.h"
#import "PGTSScannedMemoryAllocator.h"

const CFSetCallBacks kNonRetainingSetCallbacks = {
	0,
	NULL,
	NULL,
	&CFCopyDescription,
	&CFEqual,
	&CFHash
};


const CFDictionaryValueCallBacks kNonRetainingDictionaryValueCallbacks = {
	0,
	NULL,
	NULL,
	&CFCopyDescription,
	&CFEqual
};


id PGTSCreateWeakNonretainingMutableSet ()
{
	id retval = nil;
	if (PGTS::scanned_memory_allocator_env::allocate_scanned)
		retval = [NSHashTable hashTableWithWeakObjects];
	else
		retval = (id) CFSetCreateMutable (NULL, 0, &kNonRetainingSetCallbacks);
	return retval;
}


id PGTSCreateMutableDictionaryWithWeakNonretainedObjects ()
{
	id retval = nil;
	if (PGTS::scanned_memory_allocator_env::allocate_scanned)
		retval = [NSMapTable mapTableWithStrongToWeakObjects];
	else
	{
		retval = (id) CFDictionaryCreateMutable (NULL, 0, &kCFTypeDictionaryKeyCallBacks, 
												 &kNonRetainingDictionaryValueCallbacks);
		
	}
	return retval;
}


//By adding the methods to NSObject we don't override NSMapTable's implementation if one gets made.
@implementation NSObject (PGTSCollectionAdditions)
- (void) makeObjectsPerformSelector: (SEL) selector withObject: (id) object
{
	NSEnumerator* e = [(id) self objectEnumerator];
	id currentObject = nil;
	while ((currentObject = [e nextObject]))
		[currentObject performSelector: selector withObject: object];
}

- (NSArray *) objectsForKeys: (NSArray *) keys notFoundMarker: (id) marker
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [keys count]];
	NSEnumerator* e = [keys objectEnumerator];
	id currentKey = nil;
	while ((currentKey = [e nextObject]))
	{
		id object = [(id) self objectForKey: currentKey];
		if (! object)
			object = marker;
		[retval addObject: object];
	}
	return retval;
}
@end
