//
// CreateTests.m
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

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://tsnorri@localhost/basetentest"]];
    [context setAutocommits: NO];
    entity = [[context entityForTable: @"test"] retain];
    MKCAssertNotNil (context);
    MKCAssertNotNil (entity);
}

- (void) tearDown
{
    [context rollback];
    [context release];
    [entity release];
}

- (void) testCreate
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSError* error = nil;    
    MKCAssertNotNil (entity);
    
    BXDatabaseObject* object = [context createObjectForEntity: entity withFieldValues: nil error: &error];
    MKCAssertNotNil (object);
    MKCAssertNil (error);
    [context rollback];
    [pool release];
}

- (void) testCreateCustom
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSError* error = nil;
    Class objectClass = [TestObject class];
    
    [entity setDatabaseObjectClass: objectClass];
    MKCAssertEqualObjects (objectClass, [entity databaseObjectClass]);
    
    BXDatabaseObject* object = [context createObjectForEntity: entity withFieldValues: nil error: &error];
    MKCAssertNotNil (object);
    MKCAssertNil (error);
    MKCAssertTrue ([object isKindOfClass: objectClass]);    
    [context rollback];
    [pool release];
}

- (void) testCreateAndDeleteWithArray
{
    NSError* error = nil;
    NSArray* array = nil;
    array = [context executeFetchForEntity: entity withPredicate: nil returningFaults: NO 
                                    updateAutomatically: YES error: &error];
        
    MKCAssertNil (error);
    MKCAssertNotNil (array);
    unsigned int count = [array count];
    
    //Create an object into the array using another connection
    BXDatabaseContext* context2 = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://tsnorri@localhost/basetentest"]];
    [context setAutocommits: NO];
    MKCAssertNotNil (context2);
    
    BXDatabaseObject* object = [context2 createObjectForEntity: entity withFieldValues: nil error: &error];
    MKCAssertNil (error);
    MKCAssertNotNil (object);
    
    //Commit the modification so we can see some results
    [context2 save: &error];
    MKCAssertNil (error);
    
    //Wait for the notification
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 2]];
    MKCAssertEquals ([array count], count + 1);
    
    [context2 executeDeleteObject: object error: &error];
    STAssertNil (error, [error description]);

    //Again, commit
    [context2 save: &error];
    STAssertNil (error, [error description]);
    
    //Wait for the notification
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 2]];
    
    MKCAssertEquals (count, [array count]);
}

@end
