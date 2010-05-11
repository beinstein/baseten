//
// BXModificationTests.m
// BaseTen
//
// Copyright (C) 2006-2010 Marko Karppinen & Co. LLC.
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
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <Foundation/Foundation.h>

#import "BXModificationTests.h"
#import "MKCSenTestCaseAdditions.h";


@implementation BXModificationTests
- (void) test1PkeyModification
{    
    BXEntityDescription* pkeytest = [[mContext databaseObjectModel] entityForTable: @"Pkeytest"];
    NSError* error = nil;
    MKCAssertNotNil (mContext);
    MKCAssertNotNil (pkeytest);
    
    NSArray* res = [mContext executeFetchForEntity: pkeytest
                                    withPredicate: [NSPredicate predicateWithFormat: @"Id = 1"]
                                            error: &error];
    STAssertNotNil (res, [error description]);
    
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    MKCAssertEquals ([[object valueForKey: @"Id"] intValue], 1);
    MKCAssertEqualObjects ([object valueForKey: @"value"], @"a");
    
    [object setPrimitiveValue: [NSNumber numberWithInt: 4] forKey: @"Id"];
    MKCAssertEquals ([[object valueForKey: @"Id"] intValue], 4);
    [object setPrimitiveValue: @"d" forKey: @"value"];
    
    res = [[mContext executeFetchForEntity: pkeytest withPredicate: nil error: &error]
        sortedArrayUsingDescriptors: [NSArray arrayWithObject: 
            [[[NSSortDescriptor alloc] initWithKey: @"Id" ascending: YES] autorelease]]];
    STAssertNotNil (res, [error description]);

    MKCAssertTrue (3 == [res count]);
    for (int i = 0; i < 3; i++)
    {
        int number = i + 2;
        object = [res objectAtIndex: i];
        MKCAssertEquals ([[object valueForKey: @"Id"] intValue], number);
        NSString* value = [NSString stringWithFormat: @"%c", 'a' + number - 1];
        MKCAssertEqualObjects ([object valueForKey: @"value"], value);
    }
    
    [mContext rollback];
}


- (void) test2MassUpdateAndDelete
{
    BXEntityDescription* updatetest = [[mContext databaseObjectModel] entityForTable: @"updatetest"];
	MKCAssertNotNil (updatetest);
	
    NSError* error = nil;
    NSArray* res = [mContext executeFetchForEntity: updatetest withPredicate: nil
                                  returningFaults: NO error: &error];
    NSArray* originalResult = res;
    STAssertNotNil (res, [error description]);
    MKCAssertTrue (5 == [res count]);
    MKCAssertTrue (5 == [[NSSet setWithArray: [res valueForKey: @"value1"]] count]);

    NSNumber* number = [NSNumber numberWithInt: 1];
    //Doesn't really matter, which object we'll get
    BXDatabaseObject* object = [res objectAtIndex: 3];
    MKCAssertFalse ([number isEqual: [object valueForKey: @"value1"]]);
    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = %@", [object valueForKey: @"id"]];

    //First update just one object
	id value1Attr = [[updatetest attributesByName] objectForKey: @"value1"];
    STAssertNotNil ([mContext executeUpdateObject: nil
										   entity: updatetest 
										predicate: predicate
								   withDictionary: [NSDictionary dictionaryWithObject: number forKey: value1Attr]
											error: &error], [error description]);
    MKCAssertEqualObjects (number, [object valueForKey: @"value1"]);
    MKCAssertTrue (5 == [[NSSet setWithArray: [res valueForKey: @"value1"]] count]);
    
    //Then update multiple objects
    number = [NSNumber numberWithInt: 2];
    STAssertNotNil ([mContext executeUpdateObject: nil
										   entity: updatetest 
										predicate: nil
								   withDictionary: [NSDictionary dictionaryWithObject: number forKey: value1Attr]
											error: &error], [error description]);
	
    NSArray* values = [res valueForKey: @"value1"];
    MKCAssertTrue (1 == [[NSSet setWithArray: values] count]);
    MKCAssertEqualObjects (number, [values objectAtIndex: 0]);
    
    //Then update an object's primary key
    number = [NSNumber numberWithInt: -1];
	id idattr = [[updatetest attributesByName] objectForKey: @"id"];
    MKCAssertTrue (5 == [[NSSet setWithArray: [res valueForKey: @"id"]] count]);
    STAssertNotNil ([mContext executeUpdateObject: object
										   entity: updatetest
										predicate: predicate
								   withDictionary: [NSDictionary dictionaryWithObject: number forKey: idattr]
											error: &error], [error description]);
	
    MKCAssertTrue (5 == [[NSSet setWithArray: [res valueForKey: @"id"]] count]);
    MKCAssertEqualObjects ([object valueForKey: @"id"], number);
    
    //Then delete an object
    predicate = [NSPredicate predicateWithFormat: @"id = -1"];
    STAssertTrue ([mContext executeDeleteFromEntity: updatetest withPredicate: predicate error: &error], [error description]);
    res = [mContext executeFetchForEntity: updatetest withPredicate: nil
                         returningFaults: NO error: &error];
    MKCAssertTrue (4 == [res count]);
    res = [mContext executeFetchForEntity: updatetest withPredicate: predicate
                         returningFaults: NO error: &error];
    MKCAssertTrue (0 == [res count]);
    
    //Finally delete all objects
    STAssertTrue ([mContext executeDeleteFromEntity: updatetest withPredicate: nil error: &error], [error description]);
    res = [mContext executeFetchForEntity: updatetest withPredicate: nil
                         returningFaults: NO error: &error];
    MKCAssertTrue (0 == [res count]);
    originalResult = nil;
    
    [mContext rollback];
}


- (void) test3CreateAndDeleteWithArray
{	
	//Fetch a self-updating collection and expect its contents to change.
    BXEntityDescription* entity = [[[mContext databaseObjectModel] entityForTable: @"test"] retain];
	MKCAssertNotNil (entity);
	
    NSError *error = nil;
	NSArray *array = [mContext executeFetchForEntity: entity withPredicate: nil returningFaults: NO 
								 updateAutomatically: YES error: &error];
    STAssertNotNil (array, [error description]);
    NSUInteger count = [array count];
    
    //Create an object into the array using another connection.
    BXDatabaseContext* context2 = [[BXDatabaseContext alloc] initWithDatabaseURI: [self databaseURI]];
	[context2 setDelegate: self];
    [context2 setAutocommits: NO];
    MKCAssertNotNil (context2);
    
    BXDatabaseObject* object = [context2 createObjectForEntity: entity withFieldValues: nil error: &error];
    STAssertNotNil (object, [error description]);
    
    //Commit the modification so we can see some results.
    STAssertTrue ([context2 save: &error], [error description]);
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
    MKCAssertEquals ([array count], count + 1);
    
    STAssertTrue ([context2 executeDeleteObject: object error: &error], [error description]);
    
    //Again, commit.
    STAssertTrue ([context2 save: &error], [error description]);    
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
    MKCAssertEquals (count, [array count]);
	
	[context2 disconnect];
	[context2 release];
}


- (void) test3Inheritance
{
	NSError *error = nil;
	BXDatabaseContext *context2 = nil;
	BXDatabaseObject *object1 = nil, *object2 = nil;

	BXEntityDescription *entity = [[mContext databaseObjectModel] entityForTable: @"inheritanceTest2"];
	MKCAssertNotNil (entity);

	{
		context2 = [[BXDatabaseContext alloc] initWithDatabaseURI: [self databaseURI]];
		[context2 setDelegate: self];
		[context2 setAutocommits: YES];
		MKCAssertNotNil (context2);
		
		STAssertTrue ([context2 connectSync: &error], [error description]);
		
		object2 = [[context2 executeFetchForEntity: entity
									 withPredicate: [NSPredicate predicateWithFormat: @"7 == id"]
											 error: &error] lastObject];
		STAssertNotNil (object2, [error description]);
		
		[object2 setPrimitiveValue: [NSNumber numberWithInteger: 9] forKey: @"b"];
		MKCAssertEqualObjects ([object2 primitiveValueForKey: @"b"], [NSNumber numberWithInteger: 9]);
	}
		
	{
		object1 = [[mContext executeFetchForEntity: entity 
									 withPredicate: [NSPredicate predicateWithFormat: @"7 == id"]
											 error: &error] lastObject];
		STAssertNotNil (object1, [error description]);
		MKCAssertEqualObjects ([object1 primitiveValueForKey: @"b"], [NSNumber numberWithInteger: 9]);
	}
	
	{
		[object2 setPrimitiveValue: [NSNumber numberWithInteger: 10] forKey: @"b"];
		[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
	
		MKCAssertEqualObjects ([object2 primitiveValueForKey: @"b"], [NSNumber numberWithInteger: 10]);
		MKCAssertEqualObjects ([object1 primitiveValueForKey: @"b"], [NSNumber numberWithInteger: 10]);
	}
}
@end
