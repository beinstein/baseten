//
// ForeignKeyModificationTests.m
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
#import <BaseTen/BXDatabaseAdditions.h>
#import <BaseTen/BXEntityDescriptionPrivate.h>

#import "ForeignKeyModificationTests.h"
#import "MKCSenTestCaseAdditions.h"


@implementation ForeignKeyModificationTests

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
    [context setAutocommits: NO];
    MKCAssertNotNil (context);
    
    test1 		= [[context entityForTable: @"test1" inSchema: @"Fkeytest" error: nil] retain];
    test2 		= [[context entityForTable: @"test2" inSchema: @"Fkeytest" error: nil] retain];
    ototest1 	= [[context entityForTable: @"ototest1" inSchema: @"Fkeytest" error: nil] retain];
    ototest2 	= [[context entityForTable: @"ototest2" inSchema: @"Fkeytest" error: nil] retain];
    mtmtest1 	= [[context entityForTable: @"mtmtest1" inSchema: @"Fkeytest" error: nil] retain];
    mtmtest2 	= [[context entityForTable: @"mtmtest2" inSchema: @"Fkeytest" error: nil] retain];

    MKCAssertNotNil (test1);
    MKCAssertNotNil (test2);
    MKCAssertNotNil (ototest1);
    MKCAssertNotNil (ototest2);
    MKCAssertNotNil (mtmtest1);
    MKCAssertNotNil (mtmtest2);

    test1v		= [[context entityForTable: @"test1_v" inSchema: @"Fkeytest" error: nil] retain];
    test2v		= [[context entityForTable: @"test2_v" inSchema: @"Fkeytest" error: nil] retain];
    ototest1v	= [[context entityForTable: @"ototest1_v" inSchema: @"Fkeytest" error: nil] retain];
    ototest2v	= [[context entityForTable: @"ototest2_v" inSchema: @"Fkeytest" error: nil] retain];
    mtmtest1v	= [[context entityForTable: @"mtmtest1_v" inSchema: @"Fkeytest" error: nil] retain];
    mtmtest2v	= [[context entityForTable: @"mtmtest2_v" inSchema: @"Fkeytest" error: nil] retain];
	mtmrel1		= [[context entityForTable: @"mtmrel1" inSchema: @"Fkeytest" error: nil] retain];
    
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
	[test1 release];
	[test2 release];	
	[ototest1 release];
	[ototest2 release];
	[mtmtest1 release];
	[mtmtest2 release];
	[test1v release];
	[test2v release];
	[ototest1v release];
	[ototest2v release];
	[mtmtest1v release];
	[mtmtest2v release];
	[mtmrel1 release];
}

- (void) modMany: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity
{
    //Change reference in foreignObject from id=1 to id=2
    NSError* error = nil;
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
    
    MKCAssertFalse ([[foreignObject primitiveValueForKey: [oneEntity name]] isEqual: object]);
    [foreignObject setPrimitiveValue: object forKey: [oneEntity name]];
    MKCAssertEqualObjects ([foreignObject primitiveValueForKey: [oneEntity name]], object);
    
    [context rollback];
}

- (void) modOne: (BXEntityDescription *) oneEntity toMany: (BXEntityDescription *) manyEntity
{
    //Create an object to oneEntity and add referencing objects to manyEntity
    NSError* error = nil;
        
    BXDatabaseObject* object = [context createObjectForEntity: oneEntity withFieldValues: nil error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertNotNil (object);
	//If the set proxy wasn't created earlier, here it will be. This might be useful for debugging.
    STAssertTrue (0 == [[object valueForKey: [manyEntity name]] count], [[object valueForKey: [manyEntity name]] description]);
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
    
	[object setPrimitiveValue: foreignObjects forKey: [manyEntity name]];
    
    NSSet* referencedObjects = [NSSet setWithSet: [object primitiveValueForKey: [manyEntity name]]];
    MKCAssertEqualObjects (referencedObjects, foreignObjects);

    [context rollback];
}

- (void) modOne: (BXEntityDescription *) entity1 toOne: (BXEntityDescription *) entity2
{
    //Change a reference in entity1 and entity2
    
    NSError* error = nil;
	[context connectSync: &error];
    STAssertNil (error, [error localizedDescription]);
	
    MKCAssertFalse ([[[entity1 relationshipsByName] objectForKey: [entity2 name]] isToMany]);
    MKCAssertFalse ([[[entity2 relationshipsByName] objectForKey: [entity1 name]] isToMany]);
    
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
    
    BXDatabaseObject* foreignObject2 = [object valueForKey: [entity2 name]];
    MKCAssertFalse ([foreignObject1 isEqual: foreignObject2]);
    MKCAssertFalse (foreignObject1 == foreignObject2);
    MKCAssertTrue ([[foreignObject2 objectID] entity] == entity2);
    
    [object setPrimitiveValue: foreignObject1 forKey: [entity2 name]];
    NSNumber* n1 = [NSNumber numberWithInt: 1];
    MKCAssertEqualObjects (n1, [foreignObject1 primitiveValueForKey: @"r1"]);
    MKCAssertEqualObjects (n1, [object primitiveValueForKey: @"id"]);
    MKCAssertEqualObjects (n1, [foreignObject1 primitiveValueForKey: @"id"]);
    MKCAssertTrue (nil == [foreignObject2 primitiveValueForKey: @"r1"]);
    MKCAssertFalse ([n1 isEqual: [foreignObject2 primitiveValueForKey: @"id"]]);

    [context rollback];
}

- (BXDatabaseObject *) removeRefObject: (BXEntityDescription *) entity
{
    NSError* error = nil;
    NSArray* res = [context executeFetchForEntity: entity
                                    withPredicate: [NSPredicate predicateWithFormat: @"id = 1"]
                                            error: &error];
    
    STAssertNil (error, [error localizedDescription]);
    return [res objectAtIndex: 0];
}

- (void) remove1: (BXEntityDescription *) oneEntity
{
    BXDatabaseObject* object = [self removeRefObject: oneEntity];
    [object setPrimitiveValue: nil forKey: @"test2"];

    [context rollback];
}

- (void) remove2: (BXEntityDescription *) oneEntity
{
    BXDatabaseObject* object = [self removeRefObject: oneEntity];
    NSSet* refObjects = [object primitiveValueForKey: @"test2"];
    TSEnumerate (currentObject, e, [[refObjects allObjects] objectEnumerator])
        [currentObject setPrimitiveValue: nil forKey: @"test1"];
    
    [context rollback];
}

@end


@implementation ForeignKeyModificationTests (Tests)

- (void) testRemove1
{
    [self remove1: test1];
}

- (void) testRemoveView1
{
    [self remove1: test1v];
}

- (void) testRemove2
{
    [self remove2: test1];
}

- (void) testRemoveView2
{
    [self remove2: test1v];
}

- (void) testModMTO
{
    [self modMany: test2 toOne: test1];
}

- (void) testModMTOView
{
    [self modMany: test2v toOne: test1v];
}

- (void) testModOTM
{
    [self modOne: test1 toMany: test2];
}

//FIXME: this doesn't work for views because we don't provide values for the primary key.
#if 0
- (void) testModOTMView
{
    [self modOne: test1v toMany: test2v];
}
#endif

- (void) testModOTM2
{
    //FIXME: also write a view test?
	MKCAssertFalse ([context autocommits]);
	
    NSError* error = nil;
    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = %d", 1];
    MKCAssertNotNil (predicate);
    NSArray* res = [context executeFetchForEntity: test1
                                    withPredicate: predicate
                                            error: &error];
    STAssertNil (error, [error description]);
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    //Create a self-updating container to see if it interferes with object creation.
    id collection = [object valueForKey: @"test2"];
    
    NSDictionary* values = [NSDictionary dictionaryWithObjectsAndKeys:
							[object primitiveValueForKey: @"id"], @"fkt1id",
							@"test", @"value",
							nil];
    [context createObjectForEntity: test2 withFieldValues: values error: &error];
    STAssertNil (error, [error description]);
    
    collection = nil;
    [context rollback];
}

- (void) testModOTO
{
    [self modOne: ototest1 toOne: ototest2];
}

- (void) testModOTOView
{
    [self modOne: ototest1v toOne: ototest2v];
}

@end
