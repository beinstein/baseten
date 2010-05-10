//
// PropagatedModificationTests.m
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

#import "PropagatedModificationTests.h"
#import "MKCSenTestCaseAdditions.h"

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseObjectIDPrivate.h>
#import <BaseTen/BXEntityDescriptionPrivate.h>


/* We currently don't support view modifications using partial keys. */

@implementation PropagatedModificationTests

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: [self databaseURI]];
	[context setAutocommits: NO];
	NSError* error = nil;
    entity = [[context databaseObjectModel] entityForTable: @"test"];
    MKCAssertNotNil (entity);
}

- (void) tearDown
{
	[context disconnect];
    [context release];
}

- (void) testView
{
    NSString* value = @"value";
    NSString* oldValue = nil;
    [context setAutocommits: YES];

    BXEntityDescription* viewEntity = [[context databaseObjectModel] entityForTable: @"test_v"];
	MKCAssertNotNil (viewEntity);

    NSPredicate* predicate = [NSPredicate predicateWithFormat: @"id = 1"];
    MKCAssertNotNil (predicate);
    
    NSError* error = nil;
    NSArray* res = [context executeFetchForEntity: entity withPredicate: predicate error: &error];
    STAssertNotNil (res, [error description]);
    MKCAssertTrue (1 == [res count]);
    
    NSArray* res2 = [context executeFetchForEntity: viewEntity withPredicate: predicate error: &error];
    STAssertNotNil (res2, [error description]);
    MKCAssertTrue (1 == [res2 count]);
    
    BXDatabaseObject* object = [res objectAtIndex: 0];
    BXDatabaseObject* viewObject = [res2 objectAtIndex: 0];
    MKCAssertFalse ([object isFaultKey: nil]);
    MKCAssertFalse ([viewObject isFaultKey: nil]);
    oldValue = [object valueForKey: @"value"];
    MKCAssertEqualObjects ([object valueForKey: @"id"], [viewObject valueForKey: @"id"]);
    MKCAssertEqualObjects (oldValue, [viewObject valueForKey: @"value"]);
    
    [object setValue: value forKey: @"value"];
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
    MKCAssertTrue ([viewObject isFaultKey: nil]);
    MKCAssertEqualObjects ([viewObject valueForKey: @"value"], value);
    
    //Clean up
    [object setValue: oldValue forKey: @"value"];
    
    [context setAutocommits: NO];
}

@end
