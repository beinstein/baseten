//
// MTOCollectionTest.m
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

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXEnumerate.h>

#import "MKCSenTestCaseAdditions.h"
#import "MTOCollectionTest.h"
#import "UnitTestAdditions.h"


@implementation MTOCollectionTest

- (void) setUp
{
	[super setUp];

    mMtocollectiontest1 = [[mContext databaseObjectModel] entityForTable: @"mtocollectiontest1" inSchema: @"Fkeytest"];
    mMtocollectiontest2 = [[mContext databaseObjectModel] entityForTable: @"mtocollectiontest2" inSchema: @"Fkeytest"];
    MKCAssertNotNil (mMtocollectiontest1);
    MKCAssertNotNil (mMtocollectiontest2);
    
    mMtocollectiontest1v = [[mContext databaseObjectModel] entityForTable: @"mtocollectiontest1_v" inSchema: @"Fkeytest"];
    mMtocollectiontest2v = [[mContext databaseObjectModel] entityForTable: @"mtocollectiontest2_v" inSchema: @"Fkeytest"];
    MKCAssertNotNil (mMtocollectiontest1v);
    MKCAssertNotNil (mMtocollectiontest2v);
}

- (void) testModMTOCollection
{
    [self modMany: mMtocollectiontest2 toOne: mMtocollectiontest1];
}

- (void) testModMTOCollectionView
{
    [self modMany: mMtocollectiontest2v toOne: mMtocollectiontest1v];
}

- (void) modMany: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity
{
    NSError* error = nil;
        
    //Execute a fetch
    NSArray* res = [mContext executeFetchForEntity: oneEntity
									 withPredicate: nil 
											 error: &error];
    STAssertNotNil (res, [error description]);
    MKCAssertTrue (2 == [res count]);
    
    //Get an object from the result
    //Here it doesn't matter, whether there are any objects in the relationship or not.
    BXDatabaseObject* object = [res objectAtIndex: 0];
    NSCountedSet* foreignObjects = [object primitiveValueForKey: [manyEntity name]];
    NSCountedSet* foreignObjects2 = [object resolveNoncachedRelationshipNamed: [manyEntity name]];
    MKCAssertNotNil (foreignObjects);
    MKCAssertNotNil (foreignObjects2);
    MKCAssertTrue (foreignObjects != foreignObjects2);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);

    //Remove the referenced objects
    [object setValue: nil forKey: [manyEntity name]];
    MKCAssertTrue (0 == [foreignObjects count]);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    
    //Get the objects from the second table
	NSArray *res2 = [mContext executeFetchForEntity: manyEntity
									  withPredicate: nil 
											  error: &error];
    STAssertNotNil (res2, [error description]);
    NSSet* objects2 = [NSSet setWithArray: res2];
    MKCAssertTrue (3 == [objects2 count]);
    
    //Set the referenced objects. The self-updating collection should get notified when objects are added.
    [object setPrimitiveValue: objects2 forKey: [manyEntity name]];
    
    MKCAssertTrue (3 == [foreignObjects count]);
    MKCAssertEqualObjects ([NSSet setWithSet: foreignObjects], objects2);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    
    [mContext rollback];
}

- (void) testModMTOCollection2
{
    [self modMany2: mMtocollectiontest2 toOne: mMtocollectiontest1];
}

- (void) testModMTOCollectionView2
{
    [self modMany2: mMtocollectiontest2v toOne: mMtocollectiontest1v];
}

- (void) modMany2: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity
{
    NSError* error = nil;

    //Execute a fetch
    NSArray* res = [mContext executeFetchForEntity: oneEntity
                                    withPredicate: nil error: &error];
    STAssertNotNil (res, [error description]);
    MKCAssertTrue (2 == [res count]);
    
    //Get an object from the result
    BXDatabaseObject* object = [res objectAtIndex: 0];
    NSCountedSet* foreignObjects = [object valueForKey: [manyEntity name]];
    NSCountedSet* foreignObjects2 = [object resolveNoncachedRelationshipNamed: [manyEntity name]];
    MKCAssertNotNil (foreignObjects);
    MKCAssertNotNil (foreignObjects2);
    MKCAssertTrue (foreignObjects != foreignObjects2);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    MKCAssertTrue ([[object objectID] entity] == oneEntity);
    MKCAssertTrue (0 == [foreignObjects count]  || [[[foreignObjects  anyObject] objectID] entity] == manyEntity);
    MKCAssertTrue (0 == [foreignObjects2 count] || [[[foreignObjects2 anyObject] objectID] entity] == manyEntity);
 
    //Remove the referenced objects (another means than in the previous method)
    [foreignObjects removeAllObjects];
    MKCAssertTrue (0 == [foreignObjects count]);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    
    //Get the objects from the second table
	NSArray *res2 = [mContext executeFetchForEntity: manyEntity
									  withPredicate: nil 
											  error: &error];
    STAssertNotNil (res2, [error description]);
    NSSet* objects2 = [NSSet setWithArray: res2];
    MKCAssertTrue (3 == [objects2 count]);
    
    NSMutableSet* mock = [NSMutableSet set];
    BXEnumerate (currentObject, e, [objects2 objectEnumerator])
    {
        [mock addObject: currentObject];
        [foreignObjects addObject: currentObject];
        MKCAssertTrue ([mock isEqualToSet: foreignObjects]);
        MKCAssertTrue ([mock isEqualToSet: foreignObjects2]);
    }
    BXDatabaseObject* anObject = [objects2 anyObject];
    [mock removeObject: anObject];
    [foreignObjects removeObject: anObject];
    MKCAssertTrue ([mock isEqualToSet: foreignObjects]);
    MKCAssertTrue ([mock isEqualToSet: foreignObjects2]);
    
    [mContext rollback];
}

@end
 