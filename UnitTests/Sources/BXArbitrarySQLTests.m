//
// BXArbitrarySQLTests.m
// BaseTen
//
// Copyright (C) 2010 Marko Karppinen & Co. LLC.
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

#import "BXArbitrarySQLTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/PGTSConnection.h>
#import <BaseTen/PGTSResultSet.h>
#import <BaseTen/BXArraySize.h>
#import <BaseTen/BXEnumerate.h>
#import <OCMock/OCMock.h>

__strong static NSString *kKVOCtx = @"BXArbitrarySQLTestsKVOObservingContext";


@implementation BXArbitrarySQLTests
- (void) setUp
{
	[super setUp];
	
	{
		NSDictionary* connectionDictionary = [self connectionDictionary];
		mConnection = [[PGTSConnection alloc] init];
		STAssertTrue ([mConnection connectSync: connectionDictionary], [[mConnection connectionError] description]);	
		
		PGTSResultSet *res = nil;
		MKCAssertNotNil ((res = [mConnection executeQuery: @"UPDATE test SET value = null"]));
		STAssertTrue ([res querySucceeded], [[res error] description]);
	}
	
	{
		mEntity = [[[mContext databaseObjectModel] entityForTable: @"test"] retain];
		MKCAssertNotNil (mEntity);
		
		NSError *error = nil;
		NSArray *res = [mContext executeFetchForEntity: mEntity withPredicate: nil error: &error];
		STAssertNotNil (res, [error description]);
		
		BXEnumerate (currentObject, e, [res objectEnumerator])
		{
			NSInteger objectID = [[currentObject primitiveValueForKey: @"id"] integerValue];
			switch (objectID)
			{
				case 1:
					mT1 = [currentObject retain];
					break;
					
				case 2:
					mT2 = [currentObject retain];
					break;
					
				case 3:
					mT3 = [currentObject retain];
					break;
					
				case 4:
					mT4 = [currentObject retain];
					
				default:
					break;
			}
		}
	}
	
	MKCAssertNotNil (mT1);
	MKCAssertNotNil (mT2);
	MKCAssertNotNil (mT3);
	MKCAssertNotNil (mT4);
	
	NSObject *dummy = [[[NSObject alloc] init] autorelease];
	mMock = [[OCMockObject partialMockForObject: dummy] retain];
	BXDatabaseObject *objects [] = {mT1, mT2, mT3, mT4};
	
	for (unsigned int i = 0, count = BXArraySize (objects); i < count; i++)
	{
		[objects [i] addObserver: (id) mMock
					  forKeyPath: @"value" 
						 options: NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew 
						 context: kKVOCtx];
		
		if (3 != i)
		{
			// The change parameter should be a HC matcher, but such would only be needed here.
			[[mMock expect] observeValueForKeyPath: @"value" ofObject: objects [i] change: OCMOCK_ANY context: kKVOCtx];
		}
	}
	
	// mT4 is not expected to change.
	NSException *exc = [NSException exceptionWithName: NSInternalInconsistencyException
											   reason: [NSString stringWithFormat: @"Object %@ changed.", mT4]
											 userInfo: nil];
	[[[mMock stub] andThrow: exc] observeValueForKeyPath: OCMOCK_ANY ofObject: mT4 change: OCMOCK_ANY context: kKVOCtx];	
}


- (void) tearDown
{
	[[mMock stub] observeValueForKeyPath: OCMOCK_ANY ofObject: OCMOCK_ANY change: OCMOCK_ANY context: kKVOCtx];
	[mMock release];
	
	PGTSResultSet *res = nil;
	MKCAssertNotNil ((res = [mConnection executeQuery: @"UPDATE test SET value = null"]));
	STAssertTrue ([res querySucceeded], [[res error] description]);
	
	[mConnection release];
	[mEntity release];
	[mT1 release];
	[mT2 release];
	[mT3 release];
	[mT4 release];
	
	[super tearDown];
}


- (void) test1UpdateUsingSQLUPDATE
{	
	PGTSResultSet *res = nil;
	MKCAssertNotNil ((res = [mConnection executeQuery: @"UPDATE test SET value = $1 WHERE id != 4" parameters: @"test"]));
	STAssertTrue ([res querySucceeded], [[res error] description]);
	
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
	[mMock verify];
}


- (void) test2UpdateUsingSQLFunction
{
	NSString *fdecl = 
	@"CREATE FUNCTION test_update_change () RETURNS VOID AS $$ "
	@" UPDATE test SET value = 'test' WHERE id != 4; "
	@"$$ VOLATILE LANGUAGE SQL";

	NSString *queries [] = {@"BEGIN", fdecl, @"SELECT test_update_change ()", @"DROP FUNCTION test_update_change ()", @"COMMIT"};
	for (unsigned int i = 0, count = BXArraySize (queries); i < count; i++)
	{
		PGTSResultSet *res = nil;
		MKCAssertNotNil ((res = [mConnection executeQuery: queries [i]]));
		STAssertTrue ([res querySucceeded], @"Error when executing '%@': %@", queries [i], [[res error] description]);
	}
	
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
	[mMock verify];
}
@end
