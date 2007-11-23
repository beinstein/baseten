//
// MKCDictionary.h
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


#import <Foundation/Foundation.h>
#import <MKCCollections/MKCCompatibility.h>


enum MKCCollectionType
{
	kMKCCollectionTypeInteger = 0,
	kMKCCollectionTypeObject,
	kMKCCollectionTypeWeakObject
	//Perhaps more in the future, such as struct, cString, ...
};


@interface MKCDictionary : NSObject  <NSCopying, NSFastEnumeration>
{
	NSMapTable* mMapTable;
}
+ (id) dictionaryWithCapacity: (NSUInteger) capacity 
					  keyType: (enum MKCCollectionType) keyType 
					valueType: (enum MKCCollectionType) valueType;
+ (id) copyDictionaryWithCapacity: (NSUInteger) capacity 
						  keyType: (enum MKCCollectionType) keyType 
						valueType: (enum MKCCollectionType) valueType;
- (id) initWithMapTable: (NSMapTable *) mapTable;
- (NSUInteger) count;
- (id) keyEnumerator;
- (id) objectEnumerator;
- (id) dictionaryRepresentation;
- (void) removeAllObjects;

//Abstract
+ (id) copyDictionaryWithCapacity: (NSUInteger) capacity;
- (id) objectForKey: (id) aKey;
@end


@interface MKCObjectDictionary : MKCDictionary
{
}
+ (id) copyDictionaryWithCapacity: (NSUInteger) capacity strongKeys: (BOOL) strongKeys strongValues: (BOOL) strongValues;
- (id) initWithCapacity: (NSUInteger) capacity strongKeys: (BOOL) strongKeys strongValues: (BOOL) strongValues;
- (void) setObject: (id) anObject forKey: (id) aKey;
@end


@interface MKCAbstractIntegerDictionary : MKCDictionary
{
}
//Abstract
+ (id) copyDictionaryWithCapacity: (NSUInteger) capacity;
- (id) initWithCapacity: (NSUInteger) capacity;
@end


@interface MKCIntegerDictionary : MKCAbstractIntegerDictionary
{
}
- (NSUInteger) integerForKey: (id) aKey;
- (void) setInteger: (NSUInteger) anInt forKey: (id) aKey;
@end


@interface MKCIntegerKeyDictionary : MKCAbstractIntegerDictionary
{
}
- (id) objectAtIndex: (NSUInteger) anIndex;
- (void) setObject: (id) anObject atIndex: (NSUInteger) aKey;
@end
