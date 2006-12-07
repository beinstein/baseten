//
// EntityTests.m
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

#import "EntityTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseAdditions.h>


@implementation EntityTests

- (void) testHash
{
    BXDatabaseContext* ctx = [BXDatabaseContext contextWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://tsnorri@localhost/basetentest"]];

    BXEntityDescription* e1 = [ctx entityForTable: @"test2" inSchema: @"fkeytest"];
    BXEntityDescription* e2 = [ctx entityForTable: @"test2" inSchema: @"fkeytest"];

    NSSet* container3 = [NSSet setWithObject: e1];
    MKCAssertNotNil ([container3 member: e1]);
    MKCAssertNotNil ([container3 member: e2]);
    MKCAssertTrue ([container3 containsObject: e1]);
    MKCAssertTrue ([container3 containsObject: e2]);
    MKCAssertEquals ([e1 hash], [e2 hash]);
    MKCAssertEqualObjects (e1, e2);
    
    NSArray* container = [NSArray arrayWithObjects: 
        [ctx entityForTable: @"mtmrel1" inSchema: @"fkeytest"],
        [ctx entityForTable: @"mtmtest1" inSchema: @"fkeytest"],
        [ctx entityForTable: @"mtmtest2" inSchema: @"fkeytest"],
        [ctx entityForTable: @"ototest1" inSchema: @"fkeytest"],
        [ctx entityForTable: @"ototest2" inSchema: @"fkeytest"],
        [ctx entityForTable: @"test1" inSchema: @"fkeytest"],
        nil];
    NSSet* container2 = [NSSet setWithArray: container];

    TSEnumerate (currentEntity, e, [container objectEnumerator])
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

@end
