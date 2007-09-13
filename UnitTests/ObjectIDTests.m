//
// ObjectIDTests.m
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

#import "ObjectIDTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BaseTen.h>


@implementation ObjectIDTests

- (void) setUp
{
	ctx = [[BXDatabaseContext contextWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]] retain];
	[ctx setAutocommits: NO];
}

- (void) tearDown
{
	[ctx release];
}

- (void) testObjectIDWithURI
{
	NSError* error = nil;
	BXEntityDescription* entity = [ctx entityForTable: @"test" inSchema: @"public" error: &error];
	STAssertNotNil (entity, [NSString stringWithFormat: @"Entity was nil (error: %@)", error]);
	
	BXDatabaseObject* object = [[ctx executeFetchForEntity: entity 
											 withPredicate: [NSPredicate predicateWithFormat: @"id == 1"]
													 error: &error] objectAtIndex: 0];
	MKCAssertNotNil (object);
	
	BXDatabaseObjectID* objectID = [object objectID];
	NSURL* uri = [objectID URIRepresentation];
	MKCAssertNotNil (uri);
	
	//Change the URI back to a object id
	BXDatabaseContext* ctx2 = [BXDatabaseContext contextWithDatabaseURI: [ctx databaseURI]];
	BXDatabaseObjectID* objectID2 = [[[BXDatabaseObjectID alloc] initWithURI: uri context: ctx2 error: &error] autorelease];
	STAssertNil (error, [error description]);
	MKCAssertEqualObjects (objectID, objectID2);
	
	BXDatabaseObject* fault = [[ctx2 faultsWithIDs: [NSArray arrayWithObject: objectID2]] objectAtIndex: 0];
	MKCAssertNotNil (fault);
	MKCAssertFalse ([ctx2 isConnected]);
}

- (void) testInvalidObjectID
{
	NSError* error = nil;
	NSURL* uri = [NSURL URLWithString: @"/public/test?id,n=12345" relativeToURL: [ctx databaseURI]];
	BXDatabaseObjectID* anId = [[[BXDatabaseObjectID alloc] initWithURI: uri context: ctx error: &error] autorelease];
	STAssertNil (error, [error description]);
	
	[ctx connectIfNeeded: &error];
	STAssertNil (error, [error description]);
	
	BXDatabaseObject* object = [ctx objectWithID: anId error: &error];
	MKCAssertNil (object);
	MKCAssertNotNil (error);
	MKCAssertTrue ([[error domain] isEqualToString: kBXErrorDomain]);
	MKCAssertTrue ([error code] == kBXErrorObjectNotFound);
}

- (void) testValidObjectID
{
	NSError* error = nil;
	NSURL* uri = [NSURL URLWithString: @"/public/test?id,n=1" relativeToURL: [ctx databaseURI]];
	BXDatabaseObjectID* anId = [[[BXDatabaseObjectID alloc] initWithURI: uri context: ctx error: &error] autorelease];
	STAssertNil (error, [error description]);
	
	[ctx connectIfNeeded: &error];
	STAssertNil (error, [error description]);
	
	BXDatabaseObject* object = [ctx objectWithID: anId error: &error];
	MKCAssertNotNil (object);
	STAssertNil (error, [error description]);
}

- (void) testObjectIDFromAnotherContext
{
	BXDatabaseContext* ctx2 = [[[BXDatabaseContext alloc] initWithDatabaseURI: [ctx databaseURI]] autorelease];
	NSError* error = nil;
	MKCAssertNotNil (ctx2);
	
	BXEntityDescription* entity = [ctx2 entityForTable: @"test" inSchema: @"public" error: &error];
	id objectArray = [ctx2 executeFetchForEntity: entity 
						  		   withPredicate: [NSPredicate predicateWithFormat: @"id == 1"]
								 		   error: &error];
	STAssertNil (error, [error description]);
	MKCAssertNotNil (objectArray);
	
	BXDatabaseObjectID* anId = [[objectArray objectAtIndex: 0] objectID];
	MKCAssertNotNil (anId);
	
	[ctx connectIfNeeded: &error];
	STAssertNil (error, [error description]);
	
	BXDatabaseObject* anObject = [ctx objectWithID: anId error: &error];
	STAssertNil (error, [error description]);
	MKCAssertNotNil (anObject);
}

@end
