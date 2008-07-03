//
// MKCHashTable.h
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
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

@protocol NSFastEnumeration;

#import <Foundation/Foundation.h>
#import "MKCCompatibility.h"


@interface MKCHashTableEnumerator : NSEnumerator 
{
    NSHashEnumerator mEnumerator;
}
- (id) initWithEnumerator: (NSHashEnumerator) enumerator;
@end


@interface MKCHashTable : NSObject <NSCopying, NSFastEnumeration>
{
    NSHashTable* mHash;
}

+ (id) hashTable;
+ (id) hashTableWithCapacity: (NSUInteger) capacity;
+ (id) copyHashTableWithCapacity: (NSUInteger) capacity;
- (id) initWithCapacity: (NSUInteger) capacity;
- (id) initWithHash: (NSHashTable *) hash;
- (NSUInteger) count;
- (void) addObject: (id) anObject;
- (void) removeObject: (id) anObject;
- (BOOL) containsObject: (id) anObject;
- (id) member: (id) anObject;
- (id) objectEnumerator;
- (void) removeAllObjects;
- (NSArray *) allObjects;
- (id) anyObject;

@end
