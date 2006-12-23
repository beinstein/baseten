//
// MTOCollectionTest.m
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

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseAdditions.h>

#import "MKCSenTestCaseAdditions.h"
#import "MTOCollectionTest.h"


@implementation MTOCollectionTest

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
    [context setAutocommits: NO];
    [context setLogsQueries: YES];
    MKCAssertNotNil (context);
    
    mtocollectiontest1 = [context entityForTable: @"mtocollectiontest1" inSchema: @"Fkeytest"];
    mtocollectiontest2 = [context entityForTable: @"mtocollectiontest2" inSchema: @"Fkeytest"];
    MKCAssertNotNil (mtocollectiontest1);
    MKCAssertNotNil (mtocollectiontest2);
    MKCAssertEqualObjects ([mtocollectiontest1 name], @"mtocollectiontest1");
    MKCAssertEqualObjects ([mtocollectiontest2 name], @"mtocollectiontest2");
    
    mtocollectiontest1v = [context entityForTable: @"mtocollectiontest1_v" inSchema: @"Fkeytest"];
    mtocollectiontest2v = [context entityForTable: @"mtocollectiontest2_v" inSchema: @"Fkeytest"];
    MKCAssertNotNil (mtocollectiontest1v);
    MKCAssertNotNil (mtocollectiontest2v);
    MKCAssertEqualObjects ([mtocollectiontest1v name], @"mtocollectiontest1_v");
    MKCAssertEqualObjects ([mtocollectiontest2v name], @"mtocollectiontest2_v");
    [mtocollectiontest1v viewIsBasedOnEntities: [NSSet setWithObject: mtocollectiontest1]];
    [mtocollectiontest2v viewIsBasedOnEntities: [NSSet setWithObject: mtocollectiontest2]];
    [mtocollectiontest1v setPrimaryKeyFields: [[mtocollectiontest1 primaryKeyFields] valueForKey: @"name"]];
    [mtocollectiontest2v setPrimaryKeyFields: [[mtocollectiontest2 primaryKeyFields] valueForKey: @"name"]];
}

- (void) testModMTOCollection
{
    [self modMany: mtocollectiontest2 toOne: mtocollectiontest1];
}

- (void) testModMTOCollectionView
{
    [self modMany: mtocollectiontest2v toOne: mtocollectiontest1v];
}

- (void) modMany: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity
{
    NSError* error = nil;
    BOOL autocommits = [context autocommits];
    [context setAutocommits: NO];
    MKCAssertTrue (NO == [context autocommits]);
    
    [oneEntity  setTargetView: ([manyEntity isView] ? manyEntity : nil) forRelationshipNamed: @"m"];
    [manyEntity setTargetView: ([oneEntity isView]  ? oneEntity  : nil) forRelationshipNamed: @"m"];
    
    //Execute a fetch
    NSArray* res = [context executeFetchForEntity: oneEntity
                                    withPredicate: nil error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (2 == [res count]);
    
    //Get an object from the result
    //Here it doesn't matter, whether there are any objects in the relationship or not.
    BXDatabaseObject* object = [res objectAtIndex: 0];
    NSCountedSet* foreignObjects = [object valueForKey: @"m"];
    NSCountedSet* foreignObjects2 = [object valueForKey: @"m"];
    MKCAssertNotNil (foreignObjects);
    MKCAssertNotNil (foreignObjects2);
    MKCAssertTrue (foreignObjects != foreignObjects2);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);

    //Remove the referenced objects
    [object setValue: nil forKey: @"m"];
    MKCAssertTrue (0 == [foreignObjects count]);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    
    //Get the objects from the second table
    NSSet* objects2 = [NSSet setWithArray: [context executeFetchForEntity: manyEntity
                                                            withPredicate: nil error: &error]];
    MKCAssertNil (error);
    MKCAssertTrue (3 == [objects2 count]);
    
    //Set the referenced objects
    [object setValue: objects2 forKey: @"m"];
    
    MKCAssertTrue (3 == [foreignObjects count]);
    MKCAssertEqualObjects ([NSSet setWithSet: foreignObjects], objects2);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    
    [context rollback];
    [context setAutocommits: autocommits];
}

- (void) testModMTOCollection2
{
    [self modMany2: mtocollectiontest2 toOne: mtocollectiontest1];
}

- (void) testModMTOCollectionView2
{
    [self modMany2: mtocollectiontest2v toOne: mtocollectiontest1v];
}

- (void) modMany2: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity
{
    NSError* error = nil;
    BOOL autocommits = [context autocommits];
    [context setAutocommits: NO];
    MKCAssertTrue (NO == [context autocommits]);

    [oneEntity  setTargetView: ([manyEntity isView] ? manyEntity : nil) forRelationshipNamed: @"m"];
    [manyEntity setTargetView: ([oneEntity isView]  ? oneEntity  : nil) forRelationshipNamed: @"m"];

    //Execute a fetch
    NSArray* res = [context executeFetchForEntity: oneEntity
                                    withPredicate: nil error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (2 == [res count]);
    
    //Get an object from the result
    BXDatabaseObject* object = [res objectAtIndex: 0];
    NSCountedSet* foreignObjects = [object valueForKey: @"m"];
    NSCountedSet* foreignObjects2 = [object valueForKey: @"m"];
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
    NSSet* objects2 = [NSSet setWithArray: [context executeFetchForEntity: manyEntity
                                                            withPredicate: nil error: &error]];
    MKCAssertNil (error);
    MKCAssertTrue (3 == [objects2 count]);
    
    NSMutableSet* mock = [NSMutableSet set];
    TSEnumerate (currentObject, e, [objects2 objectEnumerator])
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
    
    [context rollback];
    [context setAutocommits: autocommits];
}

@end
 