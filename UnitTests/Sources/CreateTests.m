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
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSError* error = nil;    

    BXEntityDescription* entity = [[mContext entityForTable: @"test" error: nil] retain];
    MKCAssertNotNil (entity);
    
    BXDatabaseObject* object = [mContext createObjectForEntity: entity withFieldValues: nil error: &error];
    STAssertNil (error, [error description]);
    MKCAssertNotNil (object);
    [mContext rollback];
    [pool release];
}

- (void) testCreateWithFieldValues
{
	BXEntityDescription* entity = [[mContext entityForTable: @"test" error: nil] retain];
    MKCAssertNotNil (entity);
	
	NSError* error = nil;
	NSString* key = @"value";
	NSDictionary* values = [NSDictionary dictionaryWithObjectsAndKeys: @"test", key, nil];
	BXDatabaseObject* object = [mContext createObjectForEntity: entity withFieldValues: values error: &error];
	MKCAssertNotNil (object);
	STAssertNil (error, [error description]);
	MKCAssertTrue ([[object valueForKey: key] isEqual: [values valueForKey: key]]);
	[mContext rollback];
}

- (void) testCreateCustom
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSError* error = nil;
    Class objectClass = [TestObject class];
    
	BXEntityDescription* entity = [[mContext entityForTable: @"test" error: nil] retain];
    MKCAssertNotNil (entity);
	
    [entity setDatabaseObjectClass: objectClass];
    MKCAssertEqualObjects (objectClass, [entity databaseObjectClass]);
    
    BXDatabaseObject* object = [mContext createObjectForEntity: entity withFieldValues: nil error: &error];
    MKCAssertNotNil (object);
    STAssertNil (error, [error description]);
    MKCAssertTrue ([object isKindOfClass: objectClass]);    
    [mContext rollback];
    [pool release];
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
