//
// UndoTests.m
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

#import "UndoTests.h"
#import <BaseTen/BaseTen.h>
#import "MKCSenTestCaseAdditions.h"


@implementation UndoTests
- (BXDatabaseObject *) objectWithId: (unsigned int) anId entity: (BXEntityDescription *) entity
{
    NSArray* res = [mContext executeFetchForEntity: entity
                                    withPredicate: [NSPredicate predicateWithFormat: @"id = %u", anId]
                                            error: nil];
    BXDatabaseObject* object = [res objectAtIndex: 0];
    return object;
}

- (void) undoAutocommit: (BOOL) autocommit
{
    if (autocommit)
    {
        [mContext setAutocommits: YES];
        MKCAssertTrue ([mContext autocommits]);
    }
    else
    {
        MKCAssertFalse ([mContext autocommits]);
    }
    
    const unsigned int objectId = 5;
	[mContext connectSync: NULL];
    NSUndoManager* undoManager = [mContext undoManager];
    BXEntityDescription* updatetest = [[mContext databaseObjectModel] entityForTable: @"updatetest"];

    MKCAssertNotNil (undoManager);
    MKCAssertNotNil (updatetest);
    
    BXDatabaseObject* object = [self objectWithId: objectId entity: updatetest];
    NSNumber* oldValue = [object primitiveValueForKey: @"value1"];
    NSNumber* newValue = [NSNumber numberWithInt: [oldValue unsignedIntValue] + 1];
    [object setPrimitiveValue: newValue forKey: @"value1"];
    
    MKCAssertEqualObjects ([object primitiveValueForKey: @"value1"], newValue);
    NSNumber* fetchedValue = [[self objectWithId: objectId entity: updatetest] primitiveValueForKey: @"value1"];
    MKCAssertEqualObjects (fetchedValue, newValue);
    
    [undoManager undo];
	id currentValue = [object primitiveValueForKey: @"value1"];
    MKCAssertEqualObjects (currentValue, oldValue);
    fetchedValue = [[self objectWithId: objectId entity: updatetest] primitiveValueForKey: @"value1"];
    MKCAssertEqualObjects (fetchedValue, oldValue);    
}

- (void) undoWithMTORelationshipAutocommit: (BOOL) autocommit
{    
    if (YES == autocommit)
    {
        [mContext setAutocommits: YES];
        MKCAssertTrue ([mContext autocommits]);
    }
    else
    {
        MKCAssertFalse ([mContext autocommits]);
    }
    
	const unsigned int objectId = 1;
    [mContext connectIfNeeded: nil];
    NSUndoManager* undoManager = [mContext undoManager];
    MKCAssertNotNil (undoManager);	

    BXEntityDescription* test1 = [[mContext databaseObjectModel] entityForTable: @"test1" inSchema: @"Fkeytest"];
	MKCAssertNotNil (test1);

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
}

- (void) testUndoWithAutocommit
{
    [self undoAutocommit: YES];
}

- (void) testUndo
{
    [self undoAutocommit: NO];
}

- (void) testUndoWithMTORelationship
{
    [self undoWithMTORelationshipAutocommit: NO];
}

- (void) testUndoWithMTORelationshipAndAutocommit
{
    [self undoWithMTORelationshipAutocommit: YES];
}

@end
