//
// MTMCollectionTest.m
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

#import "MTMCollectionTest.h"
#import "MKCSenTestCaseAdditions.h"
#import "UnitTestAdditions.h"

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXEnumerate.h>


@implementation MTMCollectionTest

- (void) setUp
{
	[super setUp];
    
    mMtmtest1 = [mContext entityForTable: @"mtmtest1" inSchema: @"Fkeytest" error: nil];
    mMtmtest2 = [mContext entityForTable: @"mtmtest2" inSchema: @"Fkeytest" error: nil];
    MKCAssertNotNil (mMtmtest1);
    MKCAssertNotNil (mMtmtest2);
    
    mMtmtest1v = [mContext entityForTable: @"mtmtest1_v" inSchema: @"Fkeytest" error: nil];
    mMtmtest2v = [mContext entityForTable: @"mtmtest2_v" inSchema: @"Fkeytest" error: nil];
    MKCAssertNotNil (mMtmtest1v);
    MKCAssertNotNil (mMtmtest2v);
}

- (void) testModMTM
{
    [self modMany: mMtmtest1 toMany: mMtmtest2];
}

- (void) testModMTMView
{
    [self modMany: mMtmtest1v toMany: mMtmtest2v];
}

- (void) modMany: (BXEntityDescription *) entity1 toMany: (BXEntityDescription *) entity2
{
    //Once again, try to modify an object and see if another object receives the modification.
    //This time, use a many-to-many relationship.

    NSError* error = nil;
    MKCAssertTrue (NO == [mContext autocommits]);
	
    //Execute a fetch
    NSArray* res = [mContext executeFetchForEntity: entity1
                                    withPredicate: nil error: &error];
	STAssertNil (error, [error description]);
    MKCAssertTrue (4 == [res count]);
    
    //Get an object from the result
    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"value1 = 'a1'"];
    res =  [res filteredArrayUsingPredicate: predicate];
    MKCAssertTrue (1 == [res count]);
    BXDatabaseObject* object = [res objectAtIndex: 0];
    NSCountedSet* foreignObjects = [object valueForKey: [entity2 name]];
    NSCountedSet* foreignObjects2 = [object resolveNoncachedRelationshipNamed: [entity2 name]];
	
    MKCAssertNotNil (foreignObjects);
    MKCAssertNotNil (foreignObjects2);
    MKCAssertTrue (foreignObjects != foreignObjects2);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    
    //Remove the referenced objects (another means than in the previous method)
    [foreignObjects removeAllObjects];
    MKCAssertTrue (0 == [foreignObjects count]);
    MKCAssertTrue ([foreignObjects isEqualToSet: foreignObjects2]);
    
    //Get the objects from the second table
    NSSet* objects2 = [NSSet setWithArray: [mContext executeFetchForEntity: entity2
                                                            withPredicate: [NSPredicate predicateWithFormat:  @"value2 != 'd2'"]
                                                                    error: &error]];
    STAssertNil (error, [error description]);
    MKCAssertTrue (3 == [objects2 count]);
    
    NSMutableSet* mock = [NSMutableSet set];
    BXEnumerate (currentObject, e, [objects2 objectEnumerator])
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
    
    [mContext rollback];
}

@end
