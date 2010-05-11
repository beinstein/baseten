//
// BXConnectTests.m
// BaseTen
//
// Copyright (C) 2006-2010 Marko Karppinen & Co. LLC.
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

#import "BXConnectionTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BaseTen.h>


@implementation BXConnectionTests
- (void) setUp
{
	[super setUp];

    mContext = [[BXDatabaseContext alloc] init];
	[mContext setAutocommits: NO];
	[mContext setDelegate: self];
}


- (void) tearDown
{
	[mContext disconnect];
    [mContext release];
	[super tearDown];
}


- (void) waitForConnectionAttempts: (NSInteger) count
{
	for (NSInteger i = 0; i < 300; i++)
	{
		NSLog (@"Attempt %d, count %d, expected %d", i, mExpectedCount, count);
		if (count == mExpectedCount)
			break;
		
		[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 2.0]];
	}
}


- (void) test1Connect
{
    MKCAssertNoThrow ([mContext setDatabaseURI: [self databaseURI]]);
    MKCAssertNoThrow ([mContext connectIfNeeded: nil]);
}


- (void) test2Connect
{
	NSURL* uri = [self databaseURI];
	NSString* uriString = [uri absoluteString];
	uriString = [uriString stringByAppendingString: @"/"];
	uri = [NSURL URLWithString: uriString];
	
    MKCAssertNoThrow ([mContext setDatabaseURI: uri]);
    MKCAssertNoThrow ([mContext connectIfNeeded: nil]);
}


- (void) test3ConnectFail
{
    MKCAssertNoThrow ([mContext setDatabaseURI: [NSURL URLWithString: @"pgsql://localhost/anonexistantdatabase"]]);
    MKCAssertThrows ([mContext connectIfNeeded: nil]);
}


- (void) test4ConnectFail
{
    MKCAssertNoThrow ([mContext setDatabaseURI: 
        [NSURL URLWithString: @"pgsql://user@localhost/basetentest/a/malformed/database/uri"]]);
    MKCAssertThrows ([mContext connectIfNeeded: nil]);
}


- (void) test5ConnectFail
{
    MKCAssertThrows ([mContext setDatabaseURI: [NSURL URLWithString: @"invalid://user@localhost/invalid"]]);
}


- (void) test7NilURI
{
	NSError* error = nil;
	id fetched = nil;
	BXEntityDescription* entity = [[mContext databaseObjectModel] entityForTable: @"test"];
	fetched = [mContext executeFetchForEntity: entity withPredicate: nil error: &error];
	MKCAssertNotNil (error);
	fetched = [mContext createObjectForEntity: entity withFieldValues: nil error: &error];
	MKCAssertNotNil (error);
}


- (void) test6ConnectFail
{
	[mContext setDatabaseURI: [NSURL URLWithString: @"pgsql://localhost/anonexistantdatabase"]];
	[[mContext notificationCenter] addObserver: self selector: @selector (expected:) name: kBXConnectionFailedNotification object: nil];
	[[mContext notificationCenter] addObserver: self selector: @selector (unexpected:) name: kBXConnectionSuccessfulNotification object: nil];
	[mContext connectAsync];
	[self waitForConnectionAttempts: 1];
	[mContext connectAsync];
	[self waitForConnectionAttempts: 2];
	[mContext connectAsync];
	[self waitForConnectionAttempts: 3];
	STAssertTrue (3 == mExpectedCount, @"Expected 3 connection attempts while there were %d.", mExpectedCount);
}


- (void) expected: (NSNotification *) n
{
	mExpectedCount++;
}


- (void) unexpected: (NSNotification *) n
{
	STAssertTrue (NO, @"Expected connection not to have been made.");
}
@end
