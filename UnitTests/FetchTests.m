//
// FetchTests.m
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

#import "FetchTests.h"
#import "MKCSenTestCaseAdditions.h"

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseObjectIDPrivate.h>


@interface BXDatabaseObject (BXKVC)
- (id) id1;
- (id) id2;
- (id) value1;
@end


@implementation FetchTests

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
    entity = [context entityForTable: @"test" error: nil];
    MKCAssertNotNil (entity);
}

- (void) tearDown
{
    [context release];
}

- (void) testObjectWithID
{
    NSError* error = nil;
    NSNumber* idNumber = [NSNumber numberWithInt: 1];
    BXPropertyDescription* property = [BXPropertyDescription propertyWithName: @"id" entity: entity];
    BXDatabaseObjectID* anId = [BXDatabaseObjectID IDWithEntity: entity primaryKeyFields:
        [NSDictionary dictionaryWithObject: idNumber forKey: property]];
    BXDatabaseObject* object = [context objectWithID: anId error: &error];
    MKCAssertNil (error);
    MKCAssertEqualObjects ([object valueForKey: @"id"], idNumber);
    //if this is not nil, then another test has failed or the database is not in known state
    STAssertEqualObjects ([object valueForKey: @"value"], nil, @"Database is not in known state!");
}

- (void) testView
{
    NSString* value = @"value";
    NSString* oldValue = nil;
    [context setAutocommits: YES];
    [context setLogsQueries: YES];

    BXEntityDescription* viewEntity = [context entityForTable: @"test_v" error: nil];
#if 0
    [viewEntity viewIsBasedOnEntities: [NSSet setWithObject: entity]];
    [viewEntity setPrimaryKeyFields: [NSArray arrayWithObject:
        [BXPropertyDescription propertyWithName: @"id" entity: viewEntity]]];
#endif
    
    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = 1"];
    MKCAssertNotNil (predicate);
    
    NSError* error = nil;
    NSArray* res = [context executeFetchForEntity: entity withPredicate: predicate error: &error];
    STAssertNil (error, [[error userInfo] objectForKey: kBXErrorMessageKey]);
    MKCAssertNotNil (res);
    MKCAssertTrue (1 == [res count]);
    
    NSArray* res2 = [context executeFetchForEntity: viewEntity withPredicate: predicate error: &error];
    STAssertNil (error, [[error userInfo] objectForKey: kBXErrorMessageKey]);
    MKCAssertNotNil (res);
    MKCAssertTrue (1 == [res count]);
    
    BXDatabaseObject* object = [res objectAtIndex: 0];
    BXDatabaseObject* viewObject = [res2 objectAtIndex: 0];
    MKCAssertFalse ([object isFaultKey: nil]);
    MKCAssertFalse ([viewObject isFaultKey: nil]);
    oldValue = [object valueForKey: @"value"];
    MKCAssertEqualObjects ([object valueForKey: @"id"], [viewObject valueForKey: @"id"]);
    MKCAssertEqualObjects (oldValue, [viewObject valueForKey: @"value"]);
    
    [object setValue: value forKey: @"value"];
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 2]];
    MKCAssertTrue ([viewObject isFaultKey: nil]);
    MKCAssertEqualObjects ([viewObject valueForKey: @"value"], value);
    
    //Clean up
    [object setValue: oldValue forKey: @"value"];
    
    [context setAutocommits: NO];
}

- (void) testMultiColumnPkey
{
    NSError* error = nil;
    [context setLogsQueries: YES];
    [context connectIfNeeded: nil];
    
    BXEntityDescription* multicolumnpkey = [context entityForTable: @"multicolumnpkey" error: nil];
    MKCAssertNotNil (multicolumnpkey);
    NSArray* multicolumnpkeys = [context executeFetchForEntity: multicolumnpkey withPredicate: nil error: &error];
    MKCAssertNotNil (multicolumnpkeys);
    MKCAssertTrue (3 == [multicolumnpkeys  count]);
    STAssertNil (error, @"Error: %@", error);
    
    NSSortDescriptor* s1 = [[[NSSortDescriptor alloc] initWithKey: @"id1" ascending: YES] autorelease];
    NSSortDescriptor* s2 = [[[NSSortDescriptor alloc] initWithKey: @"id2" ascending: YES] autorelease];
    multicolumnpkeys = [multicolumnpkeys sortedArrayUsingDescriptors: [NSArray arrayWithObjects: s1, s2, nil]];
    
    id r1 = [multicolumnpkeys objectAtIndex: 0];
    id r2 = [multicolumnpkeys objectAtIndex: 1];
    id r3 = [multicolumnpkeys objectAtIndex: 2];
    
    NSNumber* id1 = [r1 id1];
    MKCAssertEqualObjects (id1, [NSNumber numberWithInt: 1]);
    MKCAssertEqualObjects ([r1 id2], [NSNumber numberWithInt: 1]);
    MKCAssertEqualObjects ([r1 value1], @"thevalue1");
    MKCAssertEqualObjects ([r2 id1], [NSNumber numberWithInt: 1]);
    MKCAssertEqualObjects ([r2 id2], [NSNumber numberWithInt: 2]);
    MKCAssertEqualObjects ([r2 value1], @"thevalue2");
    MKCAssertEqualObjects ([r3 id1], [NSNumber numberWithInt: 2]);
    MKCAssertEqualObjects ([r3 id2], [NSNumber numberWithInt: 3]);
    MKCAssertEqualObjects ([r3 value1], @"thevalue3");
}

@end
