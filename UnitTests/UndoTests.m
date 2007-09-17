//
// UndoTests.m
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

#import "UndoTests.h"
#import <BaseTen/BaseTen.h>
#import "MKCSenTestCaseAdditions.h"


@implementation UndoTests

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

- (BXDatabaseObject *) objectWithId: (unsigned int) anId entity: (BXEntityDescription *) entity
{
    NSArray* res = [context executeFetchForEntity: entity
                                    withPredicate: [NSPredicate predicateWithFormat: @"id = %u", anId]
                                            error: nil];
    BXDatabaseObject* object = [res objectAtIndex: 0];
    return object;
}

- (void) testUndoWithAutocommit
{
    [self undoAutocommit: YES];
}

- (void) testUndo
{
    [self undoAutocommit: NO];
}

- (void) undoAutocommit: (BOOL) autocommit
{
    const unsigned int objectId = 5;
    [context connectIfNeeded: nil];
    NSUndoManager* undoManager = [context undoManager];
    MKCAssertNotNil (undoManager);
    
    if (autocommit)
    {
        [context setAutocommits: YES];
        MKCAssertTrue ([context autocommits]);
    }
    else
    {
        MKCAssertFalse ([context autocommits]);
    }
    
    BXEntityDescription* updatetest = [context entityForTable: @"updatetest" error: nil];
    MKCAssertNotNil (updatetest);
    
    BXDatabaseObject* object = [self objectWithId: objectId entity: updatetest];
    NSNumber* oldValue = [object primitiveValueForKey: @"value1"];
    NSNumber* newValue = [NSNumber numberWithInt: [oldValue unsignedIntValue] + 1];
    [object setPrimitiveValue: newValue forKey: @"value1"];
    
    MKCAssertEqualObjects ([object primitiveValueForKey: @"value1"], newValue);
    NSNumber* fetchedValue = [[self objectWithId: objectId entity: updatetest] primitiveValueForKey: @"value1"];
    MKCAssertEqualObjects (fetchedValue, newValue);
    
    [undoManager undo];
    MKCAssertEqualObjects ([object primitiveValueForKey: @"value1"], oldValue);
    fetchedValue = [[self objectWithId: objectId entity: updatetest] primitiveValueForKey: @"value1"];
    MKCAssertEqualObjects (fetchedValue, oldValue);
    
    if (autocommit)
    {
        [context setAutocommits: NO];
        MKCAssertFalse ([context autocommits]);
    }
    else
    {
        [context rollback];
    }
}

- (void) testUndoWithMTORelationship
{
    [self undoWithMTORelationshipAutocommit: NO];
}

- (void) testUndoWithMTORelationshipAndAutocommit
{
    [self undoWithMTORelationshipAutocommit: YES];
}

- (void) undoWithMTORelationshipAutocommit: (BOOL) autocommit
{
    const unsigned int objectId = 1;
    [context connectIfNeeded: nil];
    NSUndoManager* undoManager = [context undoManager];
    MKCAssertNotNil (undoManager);
    
    if (YES == autocommit)
    {
        [context setAutocommits: YES];
        MKCAssertTrue ([context autocommits]);
    }
    else
    {
        MKCAssertFalse ([context autocommits]);
    }
    
    BXEntityDescription* test1 = [context entityForTable: @"test1" inSchema: @"Fkeytest" error: nil];
    BXDatabaseObject* object = [self objectWithId: objectId entity: test1];
    MKCAssertNotNil (object);
    
    NSMutableSet* foreignObjects = [object primitiveValueForKey: @"test2"];
    BXDatabaseObject* foreignObject = [foreignObjects anyObject];
    [foreignObjects removeObject: foreignObject];
    MKCAssertTrue (1 == [foreignObjects count]);
	//FIXME: this should really be fetched from a different database context since now we get the same object we fetched earlier.
    NSMutableSet* foreignObjects2 = [[self objectWithId: objectId entity: test1] primitiveValueForKey: @"test2"];
    MKCAssertEqualObjects (foreignObjects, foreignObjects2);
    
    [undoManager undo];
    MKCAssertTrue (2 == [foreignObjects count]);
    MKCAssertEqualObjects (foreignObjects, foreignObjects2);
    
    if (autocommit)
    {
        [context setAutocommits: YES];
        MKCAssertTrue ([context autocommits]);
    }
    else
    {
        MKCAssertFalse ([context autocommits]);
    }
}

@end
