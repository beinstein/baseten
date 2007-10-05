//
// ModificationTests.m
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
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <Foundation/Foundation.h>

#import "ModificationTests.h"
#import "MKCSenTestCaseAdditions.h";


@implementation ModificationTests

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
    [context setAutocommits: NO];
    MKCAssertFalse ([context autocommits]);
}

- (void) tearDown
{
    [context release];
}

- (void) testPkeyModification
{    
    BXEntityDescription* pkeytest = [context entityForTable: @"Pkeytest" error: nil];
    NSError* error = nil;
    MKCAssertNotNil (context);
    MKCAssertNotNil (pkeytest);
    
    NSArray* res = [context executeFetchForEntity: pkeytest
                                    withPredicate: [NSPredicate predicateWithFormat: @"Id = 1"]
                                            error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertNotNil (res);
    
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    MKCAssertEquals ([[object valueForKey: @"Id"] intValue], 1);
    MKCAssertEqualObjects ([object valueForKey: @"value"], @"a");
    
    [object setPrimitiveValue: [NSNumber numberWithInt: 4] forKey: @"Id"];
    MKCAssertEquals ([[object valueForKey: @"Id"] intValue], 4);
    [object setPrimitiveValue: @"d" forKey: @"value"];
    
    res = [[context executeFetchForEntity: pkeytest withPredicate: nil error: &error]
        sortedArrayUsingDescriptors: [NSArray arrayWithObject: 
            [[[NSSortDescriptor alloc] initWithKey: @"Id" ascending: YES] autorelease]]];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertNotNil (res);

    MKCAssertTrue (3 == [res count]);
    for (int i = 0; i < 3; i++)
    {
        int number = i + 2;
        object = [res objectAtIndex: i];
        MKCAssertEquals ([[object valueForKey: @"Id"] intValue], number);
        NSString* value = [NSString stringWithFormat: @"%c", 'a' + number - 1];
        MKCAssertEqualObjects ([object valueForKey: @"value"], value);
    }
    
    [context rollback];
}

- (void) testMassUpdateAndDelete
{
    BXEntityDescription* updatetest = [context entityForTable: @"updatetest" error: nil];
    NSError* error = nil;
    
    NSArray* res = [context executeFetchForEntity: updatetest withPredicate: nil
                                  returningFaults: NO error: &error];
    NSArray* originalResult = res;
    STAssertNil (error, [error localizedDescription]);
    MKCAssertNotNil (res);
    MKCAssertTrue (5 == [res count]);
    MKCAssertTrue (5 == [[NSSet setWithArray: [res valueForKey: @"value1"]] count]);

    NSNumber* number = [NSNumber numberWithInt: 1];
    //Doesn't really matter, which object we'll get
    BXDatabaseObject* object = [res objectAtIndex: 3];
    MKCAssertFalse ([number isEqual: [object valueForKey: @"value1"]]);
    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = %@", [object valueForKey: @"id"]];

    //First update just one object
    [context executeUpdateEntity: updatetest 
                  withDictionary: [NSDictionary dictionaryWithObject: number forKey: @"value1"]
                       predicate: predicate
                           error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertEqualObjects (number, [object valueForKey: @"value1"]);
    MKCAssertTrue (5 == [[NSSet setWithArray: [res valueForKey: @"value1"]] count]);
    
    //Then update multiple objects
    number = [NSNumber numberWithInt: 2];
    [context executeUpdateEntity: updatetest 
                  withDictionary: [NSDictionary dictionaryWithObject: number forKey: @"value1"]
                       predicate: nil
                           error: &error];
    STAssertNil (error, [error localizedDescription]);
    NSArray* values = [res valueForKey: @"value1"];
    MKCAssertTrue (1 == [[NSSet setWithArray: values] count]);
    MKCAssertEqualObjects (number, [values objectAtIndex: 0]);
    
    //Then update an object's primary key
    number = [NSNumber numberWithInt: -1];
    MKCAssertTrue (5 == [[NSSet setWithArray: [res valueForKey: @"id"]] count]);
    [context executeUpdateEntity: updatetest
                  withDictionary: [NSDictionary dictionaryWithObject: number forKey: @"id"]
                       predicate: predicate
                           error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertTrue (5 == [[NSSet setWithArray: [res valueForKey: @"id"]] count]);
    MKCAssertEqualObjects (number, [object valueForKey: @"id"]);
    
    //Then delete an object
    predicate = [NSPredicate predicateWithFormat: @"id = -1"];
    [context executeDeleteFromEntity: updatetest withPredicate: predicate error: &error];
    STAssertNil (error, [error localizedDescription]);
    res = [context executeFetchForEntity: updatetest withPredicate: nil
                         returningFaults: NO error: &error];
    MKCAssertTrue (4 == [res count]);
    res = [context executeFetchForEntity: updatetest withPredicate: predicate
                         returningFaults: NO error: &error];
    MKCAssertTrue (0 == [res count]);
    
    //Finally delete all objects
    [context executeDeleteFromEntity: updatetest withPredicate: nil error: &error];
    STAssertNil (error, [error localizedDescription]);
    res = [context executeFetchForEntity: updatetest withPredicate: nil
                         returningFaults: NO error: &error];
    MKCAssertTrue (0 == [res count]);
    originalResult = nil;
    
    [context rollback];
}

@end
