//
// ForeignKeyTests.m
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
#import <BaseTen/BXEntityDescriptionPrivate.h>
#import <BaseTen/BXRelationshipDescriptionPrivate.h>

#import "ForeignKeyTests.h"
#import "MKCSenTestCaseAdditions.h"


@implementation ForeignKeyTests

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
    [context setAutocommits: NO];
    MKCAssertNotNil (context);
    
    test1 = [context entityForTable: @"test1" inSchema: @"Fkeytest" error: nil];
    test2 = [context entityForTable: @"test2" inSchema: @"Fkeytest" error: nil];
    ototest1 = [context entityForTable: @"ototest1" inSchema: @"Fkeytest" error: nil];
    ototest2 = [context entityForTable: @"ototest2" inSchema: @"Fkeytest" error: nil];
    mtmtest1 = [context entityForTable: @"mtmtest1" inSchema: @"Fkeytest" error: nil];
    mtmtest2 = [context entityForTable: @"mtmtest2" inSchema: @"Fkeytest" error: nil];

    MKCAssertNotNil (test1);
    MKCAssertNotNil (test2);
    MKCAssertNotNil (ototest1);
    MKCAssertNotNil (ototest2);
    MKCAssertNotNil (mtmtest1);
    MKCAssertNotNil (mtmtest2);

    test1v = [context entityForTable: @"test1_v" inSchema: @"Fkeytest" error: nil];
    test2v = [context entityForTable: @"test2_v" inSchema: @"Fkeytest" error: nil];
    ototest1v = [context entityForTable: @"ototest1_v" inSchema: @"Fkeytest" error: nil];
    ototest2v = [context entityForTable: @"ototest2_v" inSchema: @"Fkeytest" error: nil];
    mtmtest1v = [context entityForTable: @"mtmtest1_v" inSchema: @"Fkeytest" error: nil];
    mtmtest2v = [context entityForTable: @"mtmtest2_v" inSchema: @"Fkeytest" error: nil];
	mtmrel1 = [context entityForTable: @"mtmrel1" inSchema: @"Fkeytest" error: nil];
    
    MKCAssertNotNil (test1v);
    MKCAssertNotNil (test2v);
    MKCAssertNotNil (ototest1v);
    MKCAssertNotNil (ototest2v);
    MKCAssertNotNil (mtmtest1v);
    MKCAssertNotNil (mtmtest2v);
	MKCAssertNotNil (mtmrel1);
}

- (void) tearDown
{
    [context release];
    context = nil;
}

- (void) testMTO
{
    [self many: test2 toOne: test1];
}

- (void) testMTOView
{
    [self many: test2v toOne: test1v];
}

- (void) many: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity
{
    NSError* error = nil;
    for (int i = 1; i <= 3; i++)
    {
        NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = %d", i];
        MKCAssertNotNil (predicate);
        NSArray* res = [context executeFetchForEntity: manyEntity
                                        withPredicate: predicate
                                                error: &error];
        STAssertNil (error, [error description]);
        MKCAssertTrue (1 == [res count]);
    
        BXDatabaseObject* object = [res objectAtIndex: 0];
		MKCAssertTrue ([object isFaultKey: [oneEntity name]]);
		
        BXDatabaseObject* foreignObject = [object primitiveValueForKey: [oneEntity name]];
		MKCAssertFalse ([object isFaultKey: [oneEntity name]]);

        //See that the object has the given entity
        MKCAssertTrue ([[object objectID] entity] == manyEntity);
        
        //The row with id == 3 has null value for the foreign key
        if (3 == i)
        {
            MKCAssertNil (foreignObject);
            MKCAssertNil ([object valueForKeyPath: @"test1.value"]);
        }
        else
        {
            MKCAssertNotNil (foreignObject);
            //See that the object has the given entity
            MKCAssertTrue ([[foreignObject objectID] entity] == oneEntity);
            MKCAssertTrue ([@"11" isEqualToString: [foreignObject valueForKey: @"value"]]);
            MKCAssertTrue ([@"11" isEqualToString: [object valueForKeyPath: @"test1.value"]]);
        }
    }
}

- (void) testOTM
{
    [self one: test1 toMany: test2];
}

- (void) testOTMView
{
    [self one: test1v toMany: test2v];
}

- (void) one: (BXEntityDescription *) oneEntity toMany: (BXEntityDescription *) manyEntity
{
    NSError* error = nil;
    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = %d", 1];
    MKCAssertNotNil (predicate);
    NSArray* res = [context executeFetchForEntity: oneEntity
                                    withPredicate: predicate
                                            error: &error];
    STAssertNil (error, [error description]);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];

    //See that the object has the given entity
    MKCAssertTrue ([[object objectID] entity] == oneEntity);
    
    BXRelationshipDescription* rel = [[manyEntity relationshipsByName] objectForKey: [oneEntity name]];
    MKCAssertNotNil (rel);
    MKCAssertFalse ([rel isToMany]);
	rel = [rel inverseRelationship];
    MKCAssertNotNil (rel);
    MKCAssertTrue ([rel isToMany]);
        
    NSSet* foreignObjects = [rel targetForObject: object error: &error];
    STAssertNil (error, [error description]);
    MKCAssertTrue (2 == [foreignObjects count]);
    NSArray* values = [foreignObjects valueForKey: @"value"];
    MKCAssertTrue ([values containsObject: @"21"]);
    MKCAssertTrue ([values containsObject: @"22"]);    
    //See that the objects have the given entities
    TSEnumerate (currentObject, e, [foreignObjects objectEnumerator])
        MKCAssertTrue ([[currentObject objectID] entity] == manyEntity);

    foreignObjects = [object valueForKey: [manyEntity name]];
    STAssertNil (error, [error description]);
    MKCAssertTrue (2 == [foreignObjects count]);
    values = [foreignObjects valueForKey: @"value"];
    MKCAssertTrue ([values containsObject: @"21"]);
    MKCAssertTrue ([values containsObject: @"22"]);
    //See that the objects have the given entities
    TSEnumerate (currentObject, e, [foreignObjects objectEnumerator])
        MKCAssertTrue ([[currentObject objectID] entity] == manyEntity);
}

- (void) testOTO
{
    [self one: ototest1 toOne: ototest2];
}

- (void) testOTOView
{
    [self one: ototest1v toOne: ototest2v];
}

- (void) one: (BXEntityDescription *) entity1 toOne: (BXEntityDescription *) entity2
{
    NSError* error = nil;
	
	[context connectIfNeeded: &error];
	STAssertNil (error, [error localizedDescription]);
	
    BXRelationshipDescription* foobar = [[entity1 relationshipsByName] objectForKey: [entity2 name]];
    MKCAssertNotNil (foobar);
    MKCAssertFalse ([foobar isToMany]);
	MKCAssertFalse ([[foobar inverseRelationship] isToMany]);

    NSArray* res = [context executeFetchForEntity: entity1 
                                    withPredicate: [NSPredicate predicateWithFormat: @"1 <= id && id <= 2"]
                                            error: &error];
    STAssertNil (error, [error description]);
    MKCAssertTrue (2 == [res count]);
    for (int i = 0; i < 2; i++)
    {
        BXDatabaseObject* object = [res objectAtIndex: i];
        
        BXDatabaseObject* foreignObject  = [object valueForKey: [entity2 name]];
        BXDatabaseObject* foreignObject2 = [foobar targetForObject: object error: &error];
        STAssertNil (error, [error description]);
        
        BXDatabaseObject* object2 = [foreignObject primitiveValueForKey: [entity1 name]];
        BXDatabaseObject* object3 = [[foobar inverseRelationship] targetForObject: foreignObject error: &error];
        STAssertNil (error, [error description]);
        
        MKCAssertTrue ([[foreignObject  objectID] entity] == entity2);
        MKCAssertTrue ([[foreignObject2 objectID] entity] == entity2);
        MKCAssertTrue ([[object  objectID] entity] == entity1);
        MKCAssertTrue ([[object2 objectID] entity] == entity1);
        MKCAssertTrue ([[object3 objectID] entity] == entity1);
        MKCAssertEqualObjects (foreignObject, foreignObject2);
        MKCAssertEqualObjects (object, object2);
        MKCAssertEqualObjects (object2, object3);

        //See that the objects have the given entities
        MKCAssertTrue ([[object  objectID] entity] == entity1);
        MKCAssertTrue ([[object2 objectID] entity] == entity1);
        MKCAssertTrue ([[object3 objectID] entity] == entity1);
        MKCAssertTrue ([[foreignObject  objectID] entity] == entity2);
        MKCAssertTrue ([[foreignObject2 objectID] entity] == entity2);

        NSNumber* value = [object valueForKey: @"id"];
        NSNumber* value2 = [foreignObject valueForKey: @"id"];
        MKCAssertFalse ([value isEqual: value2]);
    }
    
    res = [context executeFetchForEntity: entity2
                           withPredicate: [NSPredicate predicateWithFormat: @"id = 3"]
                                   error: &error];
    STAssertNil (error, [error description]);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    MKCAssertNil ([object valueForKey: [entity1 name]]);
    MKCAssertTrue ([[object objectID] entity] == entity2);
}

- (void) testMTM
{
    [self many: mtmtest1 toMany: mtmtest2];
}

- (void) testMTMView
{
    [self many: mtmtest1v toMany: mtmtest2v];
}

- (void) many: (BXEntityDescription *) entity1 toMany: (BXEntityDescription *) entity2
{
    NSError* error = nil;
    NSArray* res = [context executeFetchForEntity: entity1 withPredicate: nil error: &error];
    STAssertNil (error, [error description]);
    MKCAssertTrue (4 == [res count]);
    
    NSSet* expected1 = [NSSet setWithObjects: @"a1", @"b1", @"c1", nil];
    NSSet* expected2 = [NSSet setWithObjects: @"a2", @"b2", @"c2", nil];
    
    TSEnumerate (object, e, [res objectEnumerator])
    {
        MKCAssertTrue ([[object objectID] entity] == entity1);
        
        NSSet* foreignObjects = [object primitiveValueForKey: [entity2 name]];
        MKCAssertNotNil (foreignObjects);
        if ([@"d1" isEqualToString: [object valueForKey: @"value1"]])
        {
            MKCAssertTrue (1 == [foreignObjects count]);
            BXDatabaseObject* foreignObject = [foreignObjects anyObject];
            MKCAssertTrue ([[foreignObject objectID] entity] == entity2);

            MKCAssertEqualObjects ([foreignObject valueForKey: @"value2"], @"d2");
            NSSet* objects = [foreignObject valueForKey: [entity1 name]];
            MKCAssertTrue (1 == [objects count]);
            BXDatabaseObject* backRef = [objects anyObject];
            MKCAssertTrue ([[backRef objectID] entity] == entity1);
            MKCAssertEqualObjects ([backRef valueForKey: @"value1"], @"d1");
        }
        else
        {
            MKCAssertTrue (3 == [foreignObjects count]);
            
            NSSet* values2 = [foreignObjects valueForKey: @"value2"];
            MKCAssertEqualObjects (values2, expected2);
            
            TSEnumerate (foreignObject, e, [foreignObjects objectEnumerator])
            {
                MKCAssertTrue ([[foreignObject objectID] entity] == entity2);
                NSArray* objects = [foreignObject valueForKey: [entity1 name]];
                MKCAssertNotNil (objects);
                MKCAssertTrue (3 == [objects count]);
                
                NSSet* values1 = [objects valueForKey: @"value1"];
                MKCAssertEqualObjects (values1, expected1);
                
                TSEnumerate (backRef, e, [objects objectEnumerator])
                    MKCAssertTrue ([[backRef objectID] entity] == entity1);
            }
        }
    }
}

- (void) testMTMHelper
{
	[self MTMHelper: mtmtest1];
}

- (void) testMTMHelperView
{
	[self MTMHelper: mtmtest1v];
}

- (void) MTMHelper: (BXEntityDescription *) entity
{
	NSError* error = nil;
	NSArray* res = [context executeFetchForEntity: entity
									withPredicate: [NSPredicate predicateWithFormat: @"id = 1"]
											error: &error];
	STAssertNil (error, [error localizedDescription]);
	BXDatabaseObject* object = [res objectAtIndex: 0];
	NSSet* helperObjects = [object primitiveValueForKey: @"mtmrel1"];
	MKCAssertTrue (3 == [helperObjects count]);
	TSEnumerate (currentObject, e, [helperObjects objectEnumerator])
	{
		MKCAssertTrue ([[currentObject objectID] entity] == mtmrel1);
		MKCAssertTrue (1 == [[currentObject valueForKey: @"id1"] intValue]);
	}
}
    
@end
