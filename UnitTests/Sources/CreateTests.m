//
// CreateTests.m
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

#import "CreateTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BaseTen.h>
#import <Foundation/Foundation.h>

@interface TestObject : BXDatabaseObject
{
}
@end


@implementation TestObject
@end


@implementation CreateTests
- (void) testCreate
{
    NSError* error = nil;    
    BXEntityDescription* entity = [mContext entityForTable: @"test" error: nil];
    MKCAssertNotNil (entity);
    
    BXDatabaseObject* object = [mContext createObjectForEntity: entity withFieldValues: nil error: &error];
    STAssertNil (error, [error description]);
    MKCAssertNotNil (object);
    [mContext rollback];
}

- (void) testCreateWithFieldValues
{
	BXEntityDescription* entity = [[mContext entityForTable: @"test" error: nil] retain];
    MKCAssertNotNil (entity);
	
	NSError* error = nil;
	NSDictionary* values = [NSDictionary dictionaryWithObject: @"test" forKey: @"value"];
	BXDatabaseObject* object = [mContext createObjectForEntity: entity withFieldValues: values error: &error];
	STAssertNil (error, [error description]);
	MKCAssertNotNil (object);
	
	MKCAssertFalse ([object isFaultKey: @"value"]);
	MKCAssertTrue ([[object valueForKey: @"value"] isEqual: [values valueForKey: @"value"]]);
	[mContext rollback];
}

- (void) testCreateWithPrecomposedStringValue
{
	NSString* precomposed = @"åäöÅÄÖ";
	NSString* decomposed = @"åäöÅÄÖ";
	
	BXEntityDescription* entity = [[mContext entityForTable: @"test" error: nil] retain];
    MKCAssertNotNil (entity);
	
	NSError* error = nil;
	NSDictionary* values = [NSDictionary dictionaryWithObject: precomposed forKey: @"value"];
	BXDatabaseObject* object = [mContext createObjectForEntity: entity withFieldValues: values error: &error];
	STAssertNil (error, [error description]);
	MKCAssertNotNil (object);
	
	MKCAssertFalse ([object isFaultKey: @"value"]);
	MKCAssertTrue ([[object valueForKey: @"value"] isEqual: decomposed]);
	[mContext rollback];
}

- (void) testCreateCustom
{
    NSError* error = nil;
    Class objectClass = [TestObject class];
    
	BXEntityDescription* entity = [mContext entityForTable: @"test" error: NULL];
    MKCAssertNotNil (entity);
	
    [entity setDatabaseObjectClass: objectClass];
    MKCAssertEqualObjects (objectClass, [entity databaseObjectClass]);
    
    BXDatabaseObject* object = [mContext createObjectForEntity: entity withFieldValues: nil error: &error];
    STAssertNil (error, [error description]);
    MKCAssertNotNil (object);
	
    MKCAssertTrue ([object isKindOfClass: objectClass]);    
    [mContext rollback];
}

- (void) testCreateWithRelatedObject
{
	[mContext connectSync: NULL];
	MKCAssertTrue ([mContext isConnected]);
	
	BXEntityDescription* test1 = [mContext entityForTable: @"test1" inSchema: @"Fkeytest" error: NULL];
	BXEntityDescription* test2 = [mContext entityForTable: @"test2" inSchema: @"Fkeytest" error: NULL];
	MKCAssertNotNil (test1);
	MKCAssertNotNil (test2);
	
	NSError* error = nil;
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id == 2"];
	NSArray* res = [mContext executeFetchForEntity: test1 withPredicate: predicate error: &error];
	STAssertNotNil (res, [error description]);
	
	BXDatabaseObject* target = [res lastObject];
	MKCAssertNotNil (target);
	
	NSDictionary* values = [NSDictionary dictionaryWithObject: target forKey: @"test1"];
	BXDatabaseObject* newObject = [mContext createObjectForEntity: test2 withFieldValues: values error: &error];
	STAssertNotNil (newObject, [error description]);
	
	MKCAssertTrue ([newObject primitiveValueForKey: @"test1"] == target);
	MKCAssertTrue ([[target primitiveValueForKey: @"test2Set"] containsObject: newObject]);
	
	[mContext rollback];
}
@end
