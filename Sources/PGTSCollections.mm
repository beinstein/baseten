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

#import "BXCoreDataCompatibility.h"
#import "PGTSCollections.h"
#import "PGTSScannedMemoryAllocator.h"
#import "PGTSCFScannedMemoryAllocator.h"

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


static Boolean
EqualRelationship (const void *value1, const void *value2)
{
	Boolean retval = FALSE;
	NSRelationshipDescription* r1 = (id) value1;
	NSRelationshipDescription* r2 = (id) value2;
	if ([[r1 name] isEqualToString: [r2 name]])
	{
		if ([[r1 entity] isEqual: [r2 entity]])
			retval = TRUE;
	}
	return retval;
}


id PGTSSetCreateMutableWeakNonretaining ()
{
	id retval = nil;
	if (PGTS::scanned_memory_allocator_env::allocate_scanned)
		retval = [NSHashTable hashTableWithWeakObjects];
	else
		retval = (id) CFSetCreateMutable (NULL, 0, &kNonRetainingSetCallbacks);
	return retval;
}


id PGTSSetCreateMutableStrongRetainingCB (const CFSetCallBacks* callbacks)
{
	CFSetCallBacks cb = *callbacks;
	CFAllocatorRef allocator = NULL;
	
	if (PGTS::scanned_memory_allocator_env::allocate_scanned)
	{
		allocator = PGTSScannedMemoryAllocator ();
		cb.retain = NULL;
		cb.release = NULL;
	}
	else
	{
		cb.retain = kCFTypeSetCallBacks.retain;
		cb.release = kCFTypeSetCallBacks.release;
	}
	
	id retval = (id) CFSetCreateMutable (allocator, 0, &cb);
	return retval;
}


id PGTSSetCreateMutableStrongRetainingForNSRD ()
{
	CFSetCallBacks cb = kCFTypeSetCallBacks;
	cb.equal = &EqualRelationship;
	return PGTSSetCreateMutableStrongRetainingCB (&cb);
}


id PGTSDictionaryCreateMutableWeakNonretainedObjects ()
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
