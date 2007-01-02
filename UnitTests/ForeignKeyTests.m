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

#import "ForeignKeyTests.h"
#import "MKCSenTestCaseAdditions.h"


@implementation ForeignKeyTests

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
    [context setAutocommits: NO];
    [context setLogsQueries: NO];
    MKCAssertNotNil (context);
    
    test1 = [context entityForTable: @"test1" inSchema: @"Fkeytest"];
    test2 = [context entityForTable: @"test2" inSchema: @"Fkeytest"];
    ototest1 = [context entityForTable: @"ototest1" inSchema: @"Fkeytest"];
    ototest2 = [context entityForTable: @"ototest2" inSchema: @"Fkeytest"];
    mtmtest1 = [context entityForTable: @"mtmtest1" inSchema: @"Fkeytest"];
    mtmtest2 = [context entityForTable: @"mtmtest2" inSchema: @"Fkeytest"];

    MKCAssertNotNil (test1);
    MKCAssertNotNil (test2);
    MKCAssertNotNil (ototest1);
    MKCAssertNotNil (ototest2);
    MKCAssertNotNil (mtmtest1);
    MKCAssertNotNil (mtmtest2);
    MKCAssertEqualObjects ([test1 name], @"test1");
    MKCAssertEqualObjects ([test2 name], @"test2");
    MKCAssertEqualObjects ([ototest1 name], @"ototest1");
    MKCAssertEqualObjects ([ototest2 name], @"ototest2");
    MKCAssertEqualObjects ([mtmtest1 name], @"mtmtest1");
    MKCAssertEqualObjects ([mtmtest2 name], @"mtmtest2");

    test1v = [context entityForTable: @"test1_v" inSchema: @"Fkeytest"];
    test2v = [context entityForTable: @"test2_v" inSchema: @"Fkeytest"];
    ototest1v = [context entityForTable: @"ototest1_v" inSchema: @"Fkeytest"];
    ototest2v = [context entityForTable: @"ototest2_v" inSchema: @"Fkeytest"];
    mtmtest1v = [context entityForTable: @"mtmtest1_v" inSchema: @"Fkeytest"];
    mtmtest2v = [context entityForTable: @"mtmtest2_v" inSchema: @"Fkeytest"];
    
    MKCAssertNotNil (test1v);
    MKCAssertNotNil (test2v);
    MKCAssertNotNil (ototest1v);
    MKCAssertNotNil (ototest2v);
    MKCAssertNotNil (mtmtest1v);
    MKCAssertNotNil (mtmtest2v);
    MKCAssertEqualObjects ([test1v name], @"test1_v");
    MKCAssertEqualObjects ([test2v name], @"test2_v");
    MKCAssertEqualObjects ([ototest1v name], @"ototest1_v");
    MKCAssertEqualObjects ([ototest2v name], @"ototest2_v");
    MKCAssertEqualObjects ([mtmtest1v name], @"mtmtest1_v");
    MKCAssertEqualObjects ([mtmtest2v name], @"mtmtest2_v");
    
    //Tell the view entities what they are
    [test1v viewIsBasedOnEntities: [NSSet setWithObject: test1]];
    [test2v viewIsBasedOnEntities: [NSSet setWithObject: test2]];
    [ototest1v viewIsBasedOnEntities: [NSSet setWithObject: ototest1]];
    [ototest2v viewIsBasedOnEntities: [NSSet setWithObject: ototest2]];
    [mtmtest1v viewIsBasedOnEntities: [NSSet setWithObject: mtmtest1]];
    [mtmtest2v viewIsBasedOnEntities: [NSSet setWithObject: mtmtest2]];
    
    NSArray* pkeyfields = [NSArray arrayWithObject: @"id"];
    NSArray* viewEntities = [NSArray arrayWithObjects: test1v, test2v, ototest1v, ototest2v, mtmtest1v, mtmtest2v, nil];
    TSEnumerate (currentEntity, e, [viewEntities objectEnumerator])
        [currentEntity setPrimaryKeyFields: pkeyfields];
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
        MKCAssertNil (error);
        MKCAssertTrue (1 == [res count]);
    
        [manyEntity setTargetView: ([oneEntity isView] ? oneEntity : nil) forRelationshipNamed: @"fkt1"];
        BXDatabaseObject* object = [res objectAtIndex: 0];
        BXDatabaseObject* foreignObject = [object valueForKey: @"fkt1"];

        //See that the object has the given entity
        MKCAssertTrue ([[object objectID] entity] == manyEntity);
        
        //The row with id == 3 has null value for the foreign key
        if (3 == i)
        {
            MKCAssertNil (foreignObject);
            MKCAssertNil ([object valueForKeyPath: @"fkt1.value"]);
        }
        else
        {
            MKCAssertNotNil (foreignObject);
            //See that the object has the given entity
            MKCAssertTrue ([[foreignObject objectID] entity] == oneEntity);
            MKCAssertTrue ([@"11" isEqualToString: [foreignObject valueForKey: @"value"]]);
            MKCAssertTrue ([@"11" isEqualToString: [object valueForKeyPath: @"fkt1.value"]]);
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
    MKCAssertNil (error);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];

    //See that the object has the given entity
    MKCAssertTrue ([[object objectID] entity] == oneEntity);
    
    //-[BXDatabaseContext relationshipsByNameWithEntity:entity:] doesn't 
    //currently search the relationships recursively
    id <BXRelationshipDescription> rel = nil;
    if ([manyEntity isView] || [oneEntity isView])
        rel = [manyEntity relationshipNamed: @"fkt1" context: context];
    else
    {
        NSDictionary* rels = [context relationshipsByNameWithEntity: manyEntity entity: oneEntity];
        MKCAssertTrue (0 < [rels count]);
        rel = [rels objectForKey: @"fkt1"];
    }
    MKCAssertNotNil (rel);
    MKCAssertTrue ([rel isToManyFromEntity: oneEntity]);
        
    [oneEntity setTargetView: ([manyEntity isView] ? manyEntity : nil) forRelationshipNamed: @"fkt1"];
    NSArray* foreignObjects = [rel resolveFrom: object to: [oneEntity targetForRelationship: rel] error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (2 == [foreignObjects count]);
    NSArray* values = [foreignObjects valueForKey: @"value"];
    MKCAssertTrue ([values containsObject: @"21"]);
    MKCAssertTrue ([values containsObject: @"22"]);    
    //See that the objects have the given entities
    TSEnumerate (currentObject, e, [foreignObjects objectEnumerator])
        MKCAssertTrue ([[currentObject objectID] entity] == manyEntity);

    foreignObjects = [object valueForKey: @"fkt1"];
    MKCAssertNil (error);
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
    
    [entity1 setTargetView: ([entity2 isView] ? entity2 : nil) forRelationshipNamed: @"bar"];
    [entity2 setTargetView: ([entity1 isView] ? entity1 : nil) forRelationshipNamed: @"foo"];
    
    //-[BXDatabaseContext relationshipsByNameWithEntity:entity:] doesn't 
    //currently search the relationships recursively
    id <BXRelationshipDescription> foobar = nil;
    if ([entity1 isView] || [entity2 isView])
        foobar = [entity1 relationshipNamed: @"bar" context: context];
    else
    {
        NSDictionary* rels = [context relationshipsByNameWithEntity: entity1 entity: entity2];
        MKCAssertTrue (0 < [rels count]);
        foobar = [rels objectForKey: @"bar"];
    }    
    MKCAssertNotNil (foobar);
    MKCAssertEqualObjects ([foobar nameFromEntity: entity2], @"foo");
    MKCAssertTrue ([foobar isOneToOne]);
    MKCAssertFalse ([foobar isToManyFromEntity: entity1]);
    MKCAssertFalse ([foobar isToManyFromEntity: entity2]);

    NSArray* res = [context executeFetchForEntity: entity1 
                                    withPredicate: [NSPredicate predicateWithFormat: @"1 <= id && id <= 2"]
                                            error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (2 == [res count]);
    for (int i = 0; i < 2; i++)
    {
        BXDatabaseObject* object = [res objectAtIndex: i];
        
        BXDatabaseObject* foreignObject  = [object valueForKey: @"bar"];
        BXDatabaseObject* foreignObject2 = [foobar resolveFrom: object to: entity2 error: &error];
        MKCAssertNil (error);
        
        BXDatabaseObject* object2 = [foreignObject valueForKey: @"foo"];
        BXDatabaseObject* object3 = [foobar resolveFrom: foreignObject to: entity1 error: &error];
        MKCAssertNil (error);
        
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
    MKCAssertNil (error);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    MKCAssertNil ([object valueForKey: @"foo"]);
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
    [entity1 setTargetView: ([entity2 isView] ? entity2 : nil) forRelationshipNamed: @"mtmrel1"];
    [entity2 setTargetView: ([entity1 isView] ? entity1 : nil) forRelationshipNamed: @"mtmrel1"];
    
    NSError* error = nil;
    NSArray* res = [context executeFetchForEntity: entity1 withPredicate: nil error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (4 == [res count]);
    
    NSSet* expected1 = [NSSet setWithObjects: @"a1", @"b1", @"c1", nil];
    NSSet* expected2 = [NSSet setWithObjects: @"a2", @"b2", @"c2", nil];
    
    TSEnumerate (object, e, [res objectEnumerator])
    {
        MKCAssertTrue ([[object objectID] entity] == entity1);
        
        NSSet* foreignObjects = [object valueForKey: @"mtmrel1"];
        MKCAssertNotNil (foreignObjects);
        if ([@"d1" isEqualToString: [object valueForKey: @"value1"]])
        {
            MKCAssertTrue (1 == [foreignObjects count]);
            BXDatabaseObject* foreignObject = [foreignObjects anyObject];
            MKCAssertTrue ([[foreignObject objectID] entity] == entity2);

            MKCAssertEqualObjects ([foreignObject valueForKey: @"value2"], @"d2");
            NSSet* objects = [foreignObject valueForKey: @"mtmrel1"];
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
                NSArray* objects = [foreignObject valueForKey: @"mtmrel1"];
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

- (void) testModMTO
{
    [self modMany: test2 toOne: test1];
}

- (void) testModMTOView
{
    [self modMany: test2v toOne: test1v];
}

- (void) modMany: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity
{
    [manyEntity setTargetView: ([oneEntity  isView] ? oneEntity  : nil) forRelationshipNamed: @"fkt1"];
    [oneEntity  setTargetView: ([manyEntity isView] ? manyEntity : nil) forRelationshipNamed: @"fkt1"];

    //Change reference in foreignObject from id=1 to id=2
    NSError* error = nil;
    BOOL autocommits = [context autocommits];
    [context setAutocommits: NO];
    MKCAssertTrue (NO == [context autocommits]);
    
    NSArray* res = [context executeFetchForEntity: manyEntity
                                    withPredicate: [NSPredicate predicateWithFormat: @"id = 1"]
                                            error: &error];
    MKCAssertNotNil (res);
    STAssertNil (error, [error localizedDescription]);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* foreignObject = [res objectAtIndex: 0];
    MKCAssertTrue ([[foreignObject objectID] entity] == manyEntity);

    res = [context executeFetchForEntity: oneEntity
                                    withPredicate: [NSPredicate predicateWithFormat: @"id = 2"]
                                            error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    MKCAssertTrue ([[object objectID] entity] == oneEntity);
    
    MKCAssertFalse ([[foreignObject valueForKey: @"fkt1"] isEqual: object]);
    [foreignObject setValue: object forKey: @"fkt1"];
    MKCAssertEqualObjects ([foreignObject valueForKey: @"fkt1"], object);
    
    [context rollback];
    [context setAutocommits: autocommits];
}

- (void) testModOTM
{
    [self modOne: test1 toMany: test2];
}

- (void) testModOTMView
{
    [self modOne: test1v toMany: test2v];
}

- (void) modOne: (BXEntityDescription *) oneEntity toMany: (BXEntityDescription *) manyEntity
{
    //Create an object to oneEntity and add referencing objects to manyEntity
    NSError* error = nil;
    
    BOOL autocommits = [context autocommits];
    [context setAutocommits: NO];
    MKCAssertTrue (NO == [context autocommits]);
    
    [manyEntity setTargetView: ([oneEntity  isView] ? oneEntity  : nil) forRelationshipNamed: @"fkt1"];
    [oneEntity  setTargetView: ([manyEntity isView] ? manyEntity : nil) forRelationshipNamed: @"fkt1"];
    
    BXDatabaseObject* object = [context createObjectForEntity: oneEntity withFieldValues: nil error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertNotNil (object);
    STAssertTrue (0 == [[object valueForKey: @"fkt1"] count], [[object valueForKey: @"fkt1"] description]);
    MKCAssertTrue ([[object objectID] entity] == oneEntity);
    
    const int count = 2;
    NSMutableSet* foreignObjects = [NSMutableSet setWithCapacity: count];
    for (int i = 0; i < count; i++)
    {
        BXDatabaseObject* foreignObject = [context createObjectForEntity: manyEntity withFieldValues: nil error: &error];
        STAssertNil (error, [error localizedDescription]);
        MKCAssertNotNil (foreignObject);
        MKCAssertTrue ([[foreignObject objectID] entity] == manyEntity);
        [foreignObjects addObject: foreignObject];
    }
    MKCAssertTrue (count == [foreignObjects count]);
    
    //FIXME: Reversing this should work better, since one query would be enough.
    //i.e. [object setValue: foreignObjects forKey: @"fkt1"];
    [foreignObjects setValue: object forKey: @"fkt1"];
    
    NSSet* referencedObjects = [NSSet setWithSet: [object valueForKey: @"fkt1"]];
    MKCAssertEqualObjects (referencedObjects, foreignObjects);

    [context rollback];
    [context setAutocommits: autocommits];
}

- (void) testModOTO
{
    [self modOne: ototest1 toOne: ototest2];
}

- (void) testModOTOView
{
    [self modOne: ototest1v toOne: ototest2v];
}

- (void) modOne: (BXEntityDescription *) entity1 toOne: (BXEntityDescription *) entity2
{
    //Change a reference in entity1 and entity2
    
    MKCAssertTrue ([[entity1 relationshipNamed: @"bar" context: context] isOneToOne]);
    MKCAssertTrue ([[entity2 relationshipNamed: @"foo" context: context] isOneToOne]);
    [entity1 setTargetView: ([entity2 isView] ? entity2 : nil) forRelationshipNamed: @"bar"];
    [entity2 setTargetView: ([entity1 isView] ? entity1 : nil) forRelationshipNamed: @"foo"];
    
    NSError* error = nil;
    BOOL autocommits = [context autocommits];
    BOOL logs = [context logsQueries];
    [context setAutocommits: NO];
    [context setLogsQueries: YES];
    MKCAssertTrue (NO == [context autocommits]);

    NSArray* res = [context executeFetchForEntity: entity1
                                    withPredicate: [NSPredicate predicateWithFormat: @"id = 1"]
                                            error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    MKCAssertTrue ([[object objectID] entity] == entity1);
    
    res = [context executeFetchForEntity: entity2
                           withPredicate: [NSPredicate predicateWithFormat: @"id = 1"]
                                   error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* foreignObject1 = [res objectAtIndex: 0];
    MKCAssertTrue ([[foreignObject1 objectID] entity] == entity2);
    
    BXDatabaseObject* foreignObject2 = [object valueForKey: @"bar"];
    MKCAssertFalse ([foreignObject1 isEqual: foreignObject2]);
    MKCAssertFalse (foreignObject1 == foreignObject2);
    MKCAssertTrue ([[foreignObject2 objectID] entity] == entity2);
    
    [object setValue: foreignObject1 forKey: @"bar"];
    NSNumber* n1 = [NSNumber numberWithInt: 1];
    MKCAssertEqualObjects (n1, [object valueForKey: @"r2"]);
    MKCAssertEqualObjects (n1, [foreignObject1 valueForKey: @"r1"]);
    MKCAssertEqualObjects (n1, [object valueForKey: @"id"]);
    MKCAssertEqualObjects (n1, [foreignObject1 valueForKey: @"id"]);
    MKCAssertTrue (nil == [foreignObject2 valueForKey: @"r1"]);
    MKCAssertFalse ([n1 isEqual: [foreignObject2 valueForKey: @"id"]]);

    [context rollback];
    [context setAutocommits: autocommits];
    [context setLogsQueries: logs];
}
    
@end
