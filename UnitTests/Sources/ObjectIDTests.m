//
// ObjectIDTests.m
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

#import "ObjectIDTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BaseTen.h>


@implementation ObjectIDTests
- (void) testObjectIDWithURI
{
	BXEntityDescription* entity = [[mContext databaseObjectModel] entityForTable: @"test" inSchema: @"public"];
	MKCAssertNotNil (entity);
	
	NSError *error = nil;
	BXDatabaseObject* object = [[mContext executeFetchForEntity: entity 
											 withPredicate: [NSPredicate predicateWithFormat: @"id == 1"]
													 error: &error] objectAtIndex: 0];
	STAssertNotNil (object, [error description]);
	
	BXDatabaseObjectID* objectID = [object objectID];
	NSURL* uri = [objectID URIRepresentation];
	MKCAssertNotNil (uri);
	
	//Change the URI back to a object id
	BXDatabaseContext* ctx2 = [BXDatabaseContext contextWithDatabaseURI: [mContext databaseURI]];
	[ctx2 setDelegate: self];
	BXDatabaseObjectID* objectID2 = [[[BXDatabaseObjectID alloc] initWithURI: uri context: ctx2] autorelease];
	MKCAssertNotNil (objectID2);
	MKCAssertEqualObjects (objectID, objectID2);
	
	BXDatabaseObject* fault = [[ctx2 faultsWithIDs: [NSArray arrayWithObject: objectID2]] objectAtIndex: 0];
	MKCAssertNotNil (fault);
	MKCAssertFalse ([ctx2 isConnected]);
}

- (void) testInvalidObjectID
{
	NSURL* uri = [NSURL URLWithString: @"/public/test?id,n=12345" relativeToURL: [mContext databaseURI]];
	BXDatabaseObjectID* anId = [[[BXDatabaseObjectID alloc] initWithURI: uri context: mContext] autorelease];
	MKCAssertNotNil (anId);
	
	NSError* error = nil;
	STAssertTrue ([mContext connectIfNeeded: &error], [error description]);
	
	BXDatabaseObject* object = [mContext objectWithID: anId error: &error];
	MKCAssertNil (object);
	MKCAssertNotNil (error);
	MKCAssertTrue ([[error domain] isEqualToString: kBXErrorDomain]);
	MKCAssertTrue ([error code] == kBXErrorObjectNotFound);
}

- (void) testValidObjectID
{
	NSURL* uri = [NSURL URLWithString: @"/public/test?id,n=1" relativeToURL: [mContext databaseURI]];
	BXDatabaseObjectID* anId = [[[BXDatabaseObjectID alloc] initWithURI: uri context: mContext] autorelease];
	MKCAssertNotNil (anId);
	
	NSError* error = nil;
	STAssertTrue ([mContext connectIfNeeded: &error], [error description]);
	
	BXDatabaseObject* object = [mContext objectWithID: anId error: &error];
	STAssertNotNil (object, [error description]);
}

- (void) testObjectIDFromAnotherContext
{
	BXDatabaseContext* ctx2 = [[[BXDatabaseContext alloc] initWithDatabaseURI: [mContext databaseURI]] autorelease];
	[ctx2 setDelegate: self];
	MKCAssertNotNil (ctx2);
	
	BXEntityDescription* entity = [[ctx2 databaseObjectModel] entityForTable: @"test" inSchema: @"public"];
	MKCAssertNotNil (entity);
	
	NSError *error = nil;
	id objectArray = [ctx2 executeFetchForEntity: entity 
						  		   withPredicate: [NSPredicate predicateWithFormat: @"id == 1"]
								 		   error: &error];
	STAssertNotNil (objectArray, [error description]);
	
	BXDatabaseObjectID* anId = (id) [[objectArray objectAtIndex: 0] objectID];
	MKCAssertNotNil (anId);
	
	STAssertTrue ([mContext connectIfNeeded: &error], [error description]);
	
	BXDatabaseObject* anObject = [mContext objectWithID: anId error: &error];
	STAssertNotNil (anObject, [error description]);
	
	[ctx2 disconnect];
}

@end
