//
// MTMCollectionTest.m
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

#import "MTMCollectionTest.h"
#import "MKCSenTestCaseAdditions.h"

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseAdditions.h>


@implementation MTMCollectionTest

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
    [context setAutocommits: NO];
    [context setLogsQueries: NO];
    MKCAssertNotNil (context);
    
    mtmtest1 = [context entityForTable: @"mtmtest1" inSchema: @"Fkeytest"];
    mtmtest2 = [context entityForTable: @"mtmtest2" inSchema: @"Fkeytest"];
    MKCAssertNotNil (mtmtest1);
    MKCAssertNotNil (mtmtest2);
    MKCAssertEqualObjects ([mtmtest1 name], @"mtmtest1");
    MKCAssertEqualObjects ([mtmtest2 name], @"mtmtest2");
}

- (void) testModMTM
{
    //Once again, try to modify an object and see if another object receives the modification.
    //This time, use a many-to-many relationship.

    NSError* error = nil;
    BOOL autocommits = [context autocommits];
    [context setAutocommits: NO];
    MKCAssertTrue (NO == [context autocommits]);
    
    //Execute a fetch
    NSArray* res = [context executeFetchForEntity: mtmtest1
                                    withPredicate: nil error: &error];
    MKCAssertNil (error);
    MKCAssertTrue (4 == [res count]);
    
    //Get an object from the result
    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"value1 = 'a1'"];
    res =  [res filteredArrayUsingPredicate: predicate];
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    NSCountedSet* foreignObjects = [object valueForKey: @"mtmrel1"];
    NSCountedSet* foreignObjects2 = [object valueForKey: @"mtmrel1"];
    MKCAssertNotNil (foreignObjects);
    MKCAssertNotNil (foreignObjects2);
    MKCAssertTrue (foreignObjects != foreignObjects2);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    
    //Remove the referenced objects (another means than in the previous method)
    [foreignObjects removeAllObjects];
    MKCAssertTrue (0 == [foreignObjects count]);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    
    //Get the objects from the second table
    NSSet* objects2 = [NSSet setWithArray: [context executeFetchForEntity: mtmtest2
                                                            withPredicate: [NSPredicate predicateWithFormat:  @"value2 != 'd2'"]
                                                                    error: &error]];
    MKCAssertNil (error);
    MKCAssertTrue (3 == [objects2 count]);
    
    NSMutableSet* mock = [NSMutableSet set];
    TSEnumerate (currentObject, e, [objects2 objectEnumerator])
    {
        [mock addObject: currentObject];
        [foreignObjects addObject: currentObject];
        MKCAssertTrue ([mock isEqualToSet: foreignObjects]);
        MKCAssertTrue ([mock isEqualToSet: foreignObjects2]);
    }
    BXDatabaseObject* anObject = [objects2 anyObject];
    [mock removeObject: anObject];
    [foreignObjects removeObject: anObject];
    MKCAssertTrue ([mock isEqualToSet: foreignObjects]);
    MKCAssertTrue ([mock isEqualToSet: foreignObjects2]);
    
    [context rollback];
    [context setAutocommits: autocommits];    
}

@end
