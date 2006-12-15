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
    
    test1 = [context entityForTable: @"test1" inSchema: @"fkeytest"];
    test2 = [context entityForTable: @"test2" inSchema: @"fkeytest"];
    ototest1 = [context entityForTable: @"ototest1" inSchema: @"fkeytest"];
    ototest2 = [context entityForTable: @"ototest2" inSchema: @"fkeytest"];
    mtmtest1 = [context entityForTable: @"mtmtest1" inSchema: @"fkeytest"];
    mtmtest2 = [context entityForTable: @"mtmtest2" inSchema: @"fkeytest"];

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

    test1v = [context entityForTable: @"test1_v" inSchema: @"fkeytest"];
    test2v = [context entityForTable: @"test2_v" inSchema: @"fkeytest"];
    ototest1v = [context entityForTable: @"ototest1_v" inSchema: @"fkeytest"];
    ototest2v = [context entityForTable: @"ototest2_v" inSchema: @"fkeytest"];
    mtmtest1v = [context entityForTable: @"mtmtest1_v" inSchema: @"fkeytest"];
    mtmtest2v = [context entityForTable: @"mtmtest2_v" inSchema: @"fkeytest"];
    
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
    
    //FIXME: the view entities should be told what they are
}

- (void) tearDown
{
    [context release];
    context = nil;
}


//FIXME: make each of the tests a method which accepts one or two entity arguments
//Then make tests for tables and views which call these methods

- (void) testMTO
{
    NSError* error = nil;
    for (int i = 1; i <= 3; i++)
    {
        NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = %d", i];
        MKCAssertNotNil (predicate);
        NSArray* res = [context executeFetchForEntity: test2
                                        withPredicate: predicate
                                                error: &error];
        MKCAssertNil (error);
        MKCAssertTrue (1 == [res count]);
    
        BXDatabaseObject* object = [res objectAtIndex: 0];
        BXDatabaseObject* foreignObject = [object valueForKey: @"fkt1"];
        
        //The row with id == 3 has null value for the foreign key
        if (3 == i)
        {
            MKCAssertNil (foreignObject);
            MKCAssertNil ([object valueForKeyPath: @"fkt1.value"]);
        }
        else
        {
            MKCAssertNotNil (foreignObject);
            MKCAssertTrue ([@"11" isEqualToString: [foreignObject valueForKey: @"value"]]);
            MKCAssertTrue ([@"11" isEqualToString: [object valueForKeyPath: @"fkt1.value"]]);
        }
    }
}

- (void) testOTM
{
    NSError* error = nil;
    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = %d", 1];
    MKCAssertNotNil (predicate);
    NSArray* res = [context executeFetchForEntity: test1
                                    withPredicate: predicate
                                            error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];

    NSDictionary* rels = [context relationshipsByNameWithEntity: test2 entity: test1];
    MKCAssertTrue (0 < [rels count]);
    id <BXRelationshipDescription> rel = [rels objectForKey: @"fkt1"];
    MKCAssertNotNil (rel);
    MKCAssertTrue ([rel isToManyFromEntity: test1]);
    
    NSArray* foreignObjects = [rel resolveFrom: object error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (2 == [foreignObjects count]);
    NSArray* values = [foreignObjects valueForKey: @"value"];
    MKCAssertTrue ([values containsObject: @"21"]);
    MKCAssertTrue ([values containsObject: @"22"]);
}

- (void) testOTM2
{
    NSError* error = nil;
    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = %d", 1];
    MKCAssertNotNil (predicate);
    NSArray* res = [context executeFetchForEntity: test1
                                    withPredicate: predicate
                                            error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];

    NSArray* foreignObjects = [object valueForKey: @"fkt1"];
    MKCAssertNil (error);
    MKCAssertTrue (2 == [foreignObjects count]);
    NSArray* values = [foreignObjects valueForKey: @"value"];
    MKCAssertTrue ([values containsObject: @"21"]);
    MKCAssertTrue ([values containsObject: @"22"]);
}

- (void) testOTO
{
    NSError* error = nil;
    NSDictionary* rels = [context relationshipsByNameWithEntity: ototest1 entity: ototest2];
    MKCAssertTrue (0 < [rels count]);
    id <BXRelationshipDescription> foobar = [rels objectForKey: @"bar"];
    MKCAssertNotNil (foobar);
    MKCAssertEqualObjects ([foobar nameFromEntity: ototest2], @"foo");
    MKCAssertTrue ([foobar isOneToOne]);
    MKCAssertFalse ([foobar isToManyFromEntity: ototest1]);
    MKCAssertFalse ([foobar isToManyFromEntity: ototest2]);

    NSArray* res = [context executeFetchForEntity: ototest1 
                                    withPredicate: [NSPredicate predicateWithFormat: @"1 <= id && id <= 2"]
                                            error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (2 == [res count]);
    for (int i = 0; i < 2; i++)
    {
        BXDatabaseObject* object = [res objectAtIndex: i];
        
        BXDatabaseObject* foreignObject  = [object valueForKey: @"bar"];
        BXDatabaseObject* foreignObject2 = [foobar resolveFrom: object error: &error];
        MKCAssertNil (error);
        MKCAssertEqualObjects (foreignObject, foreignObject2);
        
        BXDatabaseObject* object2 = [foreignObject valueForKey: @"foo"];
        BXDatabaseObject* object3 = [foobar resolveFrom: foreignObject error: &error];
        MKCAssertNil (error);
        MKCAssertEqualObjects (object, object2);
        MKCAssertEqualObjects (object2, object3);
        
        NSNumber* value = [object valueForKey: @"id"];
        NSNumber* value2 = [foreignObject valueForKey: @"id"];
        MKCAssertFalse ([value isEqual: value2]);
    }
    
    res = [context executeFetchForEntity: ototest2
                           withPredicate: [NSPredicate predicateWithFormat: @"id = 3"]
                                   error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    MKCAssertNil ([object valueForKey: @"foo"]);
}

- (void) testMTM
{
    NSError* error = nil;
    NSArray* res = [context executeFetchForEntity: mtmtest1 withPredicate: nil error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (4 == [res count]);
    
    NSSet* expected1 = [NSSet setWithObjects: @"a1", @"b1", @"c1", nil];
    NSSet* expected2 = [NSSet setWithObjects: @"a2", @"b2", @"c2", nil];
    
    TSEnumerate (object, e, [res objectEnumerator])
    {
        NSSet* foreignObjects = [object valueForKey: @"mtmrel1"];
        MKCAssertNotNil (foreignObjects);
        if ([@"d1" isEqualToString: [object valueForKey: @"value1"]])
        {
            MKCAssertTrue (1 == [foreignObjects count]);
            BXDatabaseObject* foreignObject = [foreignObjects anyObject];
            
            MKCAssertEqualObjects ([foreignObject valueForKey: @"value2"], @"d2");
            NSSet* objects = [foreignObject valueForKey: @"mtmrel1"];
            MKCAssertTrue (1 == [objects count]);
            BXDatabaseObject* backRef = [objects anyObject];
            MKCAssertEqualObjects ([backRef valueForKey: @"value1"], @"d1");
        }
        else
        {
            MKCAssertTrue (3 == [foreignObjects count]);
            
            NSSet* values2 = [foreignObjects valueForKey: @"value2"];
            MKCAssertEqualObjects (values2, expected2);
            
            TSEnumerate (foreignObject, e, [foreignObjects objectEnumerator])
            {
                NSArray* objects = [foreignObject valueForKey: @"mtmrel1"];
                MKCAssertNotNil (objects);
                MKCAssertTrue (3 == [objects count]);
                
                NSSet* values1 = [objects valueForKey: @"value1"];
                MKCAssertEqualObjects (values1, expected1);
            }
        }
    }
}

- (void) testModMTO
{
    //Change reference in foreignObject from id=1 to id=2
    NSError* error = nil;
    BOOL autocommits = [context autocommits];
    [context setAutocommits: NO];
    MKCAssertTrue (NO == [context autocommits]);
    
    NSArray* res = [context executeFetchForEntity: test2 
                                    withPredicate: [NSPredicate predicateWithFormat: @"id = 1"]
                                            error: &error];
    MKCAssertNotNil (res);
    STAssertNil (error, [error localizedDescription]);
    BXDatabaseObject* foreignObject = [res objectAtIndex: 0];
    
    res = [context executeFetchForEntity: test1
                                    withPredicate: [NSPredicate predicateWithFormat: @"id = 2"]
                                            error: &error];
    STAssertNil (error, [error localizedDescription]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    
    
    MKCAssertFalse ([[foreignObject valueForKey: @"fkt1"] isEqual: object]);
    [foreignObject setValue: object forKey: @"fkt1"];
    MKCAssertEqualObjects ([foreignObject valueForKey: @"fkt1"], object);
    
    [context rollback];
    [context setAutocommits: autocommits];
}

- (void) testModOTM
{
    //Create and object to test1 and add referencing objects to test2
    NSError* error = nil;
    
    BOOL autocommits = [context autocommits];
    [context setAutocommits: NO];
    MKCAssertTrue (NO == [context autocommits]);
    
    BXDatabaseObject* object = [context createObjectForEntity: test1 withFieldValues: nil error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertNotNil (object);
    
    STAssertTrue (0 == [[object valueForKey: @"fkt1"] count], [[object valueForKey: @"fkt1"] description]);
    
    const int count = 2;
    NSMutableSet* foreignObjects = [NSMutableSet setWithCapacity: count];
    for (int i = 0; i < count; i++)
    {
        BXDatabaseObject* foreignObject = [context createObjectForEntity: test2 withFieldValues: nil error: &error];
        STAssertNil (error, [error localizedDescription]);
        MKCAssertNotNil (foreignObject);
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
    //Change a reference in ototest1 and ototest2
    NSError* error = nil;
    BOOL autocommits = [context autocommits];
    [context setAutocommits: NO];
    MKCAssertTrue (NO == [context autocommits]);

    NSArray* res = [context executeFetchForEntity: ototest1
                                    withPredicate: [NSPredicate predicateWithFormat: @"id = 1"]
                                            error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    
    res = [context executeFetchForEntity: ototest2
                           withPredicate: [NSPredicate predicateWithFormat: @"id = 1"]
                                   error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* foreignObject1 = [res objectAtIndex: 0];
    
    BXDatabaseObject* foreignObject2 = [object valueForKey: @"bar"];
    MKCAssertFalse ([foreignObject1 isEqual: foreignObject2]);
    MKCAssertFalse (foreignObject1 == foreignObject2);
    
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
}
    
@end
