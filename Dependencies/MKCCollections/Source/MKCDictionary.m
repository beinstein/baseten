//
// MKCDictionary.m
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


#import "MKCDictionaryPrivate.h"
#import "MKCDictionaryEnumerators.h"


@implementation MKCDictionary

+ (id) dictionaryWithKeyType: (enum MKCCollectionType) keyType 
                   valueType: (enum MKCCollectionType) valueType;
{
    return [self dictionaryWithCapacity: 0 keyType: keyType valueType: valueType];
}

+ (id) dictionaryWithCapacity: (NSUInteger) capacity 
					  keyType: (enum MKCCollectionType) keyType 
					valueType: (enum MKCCollectionType) valueType
{
	return [[self copyDictionaryWithCapacity: capacity keyType: keyType valueType: valueType] autorelease];
}

+ (id) copyDictionaryWithKeyType: (enum MKCCollectionType) keyType 
                       valueType: (enum MKCCollectionType) valueType;
{
    return [self copyDictionaryWithCapacity: 0 keyType: keyType valueType: valueType];
}

+ (id) copyDictionaryWithCapacity: (NSUInteger) capacity 
						  keyType: (enum MKCCollectionType) keyType 
						valueType: (enum MKCCollectionType) valueType
{
	id retval = nil;
	if (kMKCCollectionTypeInteger == keyType && kMKCCollectionTypeObject == valueType)
		retval = [MKCIntegerKeyDictionary copyDictionaryWithCapacity: capacity];
	else if (kMKCCollectionTypeObject == keyType && kMKCCollectionTypeInteger == valueType)
		retval = [MKCIntegerDictionary copyDictionaryWithCapacity: capacity];
	else if (kMKCCollectionTypeObject == keyType && kMKCCollectionTypeWeakObject == valueType)
		retval = [MKCObjectDictionary copyDictionaryWithCapacity: capacity strongKeys: YES strongValues: NO];
	else if (kMKCCollectionTypeWeakObject == keyType && kMKCCollectionTypeObject == valueType)
		retval = [MKCObjectDictionary copyDictionaryWithCapacity: capacity strongKeys: NO strongValues: YES];
	else
	{
		NSString* reason = [NSString stringWithFormat: @"Unexpected key and value types: %d %d.", keyType, valueType];
		@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: reason userInfo: nil];
	}
	return retval;
}

+ (id) copyDictionaryWithCapacity: (NSUInteger) capacity
{
	@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: @"Unexpected initializer." userInfo: nil];
	return nil;
}

- (id) initWithMapTable: (NSMapTable *) mapTable;
{
	if ((self = [super init]))
	{
		mMapTable = mapTable;
	}
	return self;
}

- (NSUInteger) count
{
	return NSCountMapTable (mMapTable);
}

- (void) dealloc
{
	NSFreeMapTable (mMapTable);
	[super dealloc];
}

- (id) keyEnumerator
{
	return [[[MKCDictionaryKeyEnumerator allocWithZone: [self zone]] initWithEnumerator: NSEnumerateMapTable (mMapTable)] autorelease];
}

- (id) objectEnumerator
{
	return [[[MKCDictionaryEnumerator allocWithZone: [self zone]] initWithEnumerator: NSEnumerateMapTable (mMapTable)] autorelease];
}

- (id) copyWithZone: (NSZone *) zone
{
	return [[[self class] allocWithZone: zone] initWithMapTable: NSCopyMapTableWithZone (mMapTable, zone)];
}

- (id) dictionaryRepresentation
{
	NSMutableDictionary* retval = [NSMutableDictionary dictionary];
	NSEnumerator* e = [self keyEnumerator];
	id currentKey = nil;
	while ((currentKey = [e nextObject]))
		[retval setObject: [self objectForKey: currentKey] forKey: currentKey];
	return retval;
}

- (void) removeAllObjects
{
	NSResetMapTable (mMapTable);
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *) state objects: (id *) stackbuf count: (NSUInteger) len
{
	return [(id) mMapTable countByEnumeratingWithState: state objects: stackbuf count: len];
}

- (id) objectForKey: (id) aKey
{
	@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: @"This is an abstract class." userInfo: nil];
	return nil;
}

- (void) setObject: (id) anObject forKey: (id) aKey
{
	@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: @"This is an abstract class." userInfo: nil];
}

- (NSUInteger) integerForKey: (id) aKey
{
	@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: @"This is an abstract class." userInfo: nil];
	return 0;
}

- (void) setInteger: (NSUInteger) anInt forKey: (id) aKey
{
	@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: @"This is an abstract class." userInfo: nil];
}

- (id) objectAtIndex: (NSUInteger) anIndex
{
	@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: @"This is an abstract class." userInfo: nil];
	return nil;
}

- (void) setObject: (id) anObject atIndex: (NSUInteger) aKey
{
	@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: @"This is an abstract class." userInfo: nil];
}

- (id) allKeys
{
	@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: @"This is an abstract class." userInfo: nil];
	return nil;
}

- (id) allObjects
{
	@throw [NSException exceptionWithName: NSInternalInconsistencyException reason: @"This is an abstract class." userInfo: nil];
	return nil;
}

@end

