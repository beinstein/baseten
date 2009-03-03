//
// EntityTests.m
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

#import "EntityTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXEnumerate.h>


@implementation EntityTests

- (void) setUp
{
	ctx = [[BXDatabaseContext contextWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]] retain];
	[ctx setAutocommits: NO];
}

- (void) tearDown
{
	[ctx disconnect];
	[ctx release];
}

- (void) testValidName
{
	NSError* error = nil;
	NSString* schemaName = @"Fkeytest";
	NSString* entityName = @"mtocollectiontest1";
	BXEntityDescription* entity = [ctx entityForTable: entityName inSchema: schemaName error: &error];
	STAssertNil (error, [error description]);
	MKCAssertNotNil (entity);
	MKCAssertEqualObjects ([entity name], entityName);
	MKCAssertEqualObjects ([entity schemaName], schemaName);
}

- (void) testInvalidName
{
	NSError* error = nil;
	NSString* schemaName = @"public";
	NSString* entityName = @"aNonExistentTable";
	[ctx connectIfNeeded: &error];
	BXEntityDescription* entity = [ctx entityForTable: entityName inSchema: schemaName error: &error];
	MKCAssertNotNil (error);
	MKCAssertNil (entity);
}

- (void) testValidation
{
	NSError* error = nil;
	[ctx connectIfNeeded: &error];
	//This entity has fields only some of which are primary key.
	BXEntityDescription* entity = [ctx entityForTable: @"mtmtest2" inSchema: @"Fkeytest" error: &error];
	STAssertNotNil (entity, [NSString stringWithFormat: @"Entity was nil (error: %@)", error]);
	
	//The entity should be validated
	MKCAssertNotNil ([entity fields]);
	MKCAssertNotNil ([entity primaryKeyFields]);	
}

- (void) testSharing
{
	NSError* error = nil;
	NSString* entityName = @"mtocollectiontest1";
	NSString* schemaName = @"Fkeytest";
	BXEntityDescription* entity = [ctx entityForTable: entityName inSchema: schemaName error: &error];
	STAssertNotNil (entity, [NSString stringWithFormat: @"Entity was nil (error: %@)", error]);
	
	BXDatabaseContext* ctx2 = [BXDatabaseContext contextWithDatabaseURI: [ctx databaseURI]];
	BXEntityDescription* entity2 = [ctx2 entityForTable: entityName inSchema: schemaName error: &error];
	STAssertNotNil (entity, [NSString stringWithFormat: @"Entity was nil (error: %@)", error]);
	MKCAssertTrue (entity == entity2);
}

- (void) testExclusion
{
	[ctx setLogsQueries: YES];
	[ctx connectSync: NULL];
	[ctx setLogsQueries: YES];
	
	NSError* error = nil;
	BXEntityDescription* entity = [ctx entityForTable: @"test" error: &error];
	STAssertNotNil (entity, [error description]);
	
	BXAttributeDescription* attr = [[entity attributesByName] objectForKey: @"xmin"];
	MKCAssertNotNil (attr);
	MKCAssertTrue ([attr isExcluded]);
	attr = [[entity attributesByName] objectForKey: @"id"];
	MKCAssertNotNil (attr);
	MKCAssertFalse ([attr isExcluded]);
	attr = [[entity attributesByName] objectForKey: @"value"];
	MKCAssertNotNil (attr);
	MKCAssertFalse ([attr isExcluded]);
}

- (void) testHash
{
    BXEntityDescription* e1 = [ctx entityForTable: @"test2" inSchema: @"Fkeytest" error: nil];
    BXEntityDescription* e2 = [ctx entityForTable: @"test2" inSchema: @"Fkeytest" error: nil];

    NSSet* container3 = [NSSet setWithObject: e1];
    MKCAssertNotNil ([container3 member: e1]);
    MKCAssertNotNil ([container3 member: e2]);
    MKCAssertTrue ([container3 containsObject: e1]);
    MKCAssertTrue ([container3 containsObject: e2]);
    MKCAssertEquals ([e1 hash], [e2 hash]);
    MKCAssertEqualObjects (e1, e2);
    
    NSArray* container = [NSArray arrayWithObjects: 
        [ctx entityForTable: @"mtmrel1"  inSchema: @"Fkeytest" error: nil],
        [ctx entityForTable: @"mtmtest1" inSchema: @"Fkeytest" error: nil],
        [ctx entityForTable: @"mtmtest2" inSchema: @"Fkeytest" error: nil],
        [ctx entityForTable: @"ototest1" inSchema: @"Fkeytest" error: nil],
        [ctx entityForTable: @"ototest2" inSchema: @"Fkeytest" error: nil],
        [ctx entityForTable: @"test1"    inSchema: @"Fkeytest" error: nil],
        nil];
    NSSet* container2 = [NSSet setWithArray: container];

    BXEnumerate (currentEntity, e, [container objectEnumerator])
    {
        MKCAssertFalse ([e1 hash] == [currentEntity hash]);
        MKCAssertFalse ([e2 hash] == [currentEntity hash]);
        MKCAssertFalse ([e1 isEqualTo: currentEntity]);
        MKCAssertFalse ([e2 isEqualTo: currentEntity]);
        MKCAssertTrue ([container containsObject: currentEntity]);
        MKCAssertTrue ([container2 containsObject: currentEntity]);
        MKCAssertNotNil ([container2 member: currentEntity]);
    }

    MKCAssertFalse ([container containsObject: e1]);
    MKCAssertFalse ([container containsObject: e2]);
    MKCAssertFalse ([container2 containsObject: e1]);
    MKCAssertFalse ([container2 containsObject: e2]);    
}

- (void) testViewPkey
{
	NSError* error = nil;
	[ctx connectIfNeeded: &error];
	BXEntityDescription* entity = [ctx entityForTable: @"test_v" error: &error];
	STAssertNotNil (entity, [NSString stringWithFormat: @"Entity was nil (error: %@)", error]);
	
	NSArray* pkeyFields = [entity primaryKeyFields];
	MKCAssertTrue (1 == [pkeyFields count]);
	MKCAssertEqualObjects (@"id", [[pkeyFields lastObject] name]);
}
@end
