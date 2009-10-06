//
// ConnectTest.m
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

#import "ConnectTest.h"
#import <BaseTen/BaseTen.h>
#import "MKCSenTestCaseAdditions.h"


@implementation ConnectTest

- (void) setUp
{
	[super setUp];
	
    ctx = [[BXDatabaseContext alloc] init];
	[ctx setAutocommits: NO];
	[ctx setDelegate: self];
	expectedCount = 0;
}

- (void) tearDown
{
	[ctx disconnect];
    [ctx release];
	[super tearDown];
}

- (void) testConnect1
{
    MKCAssertNoThrow ([ctx setDatabaseURI: [self databaseURI]]);
    MKCAssertNoThrow ([ctx connectIfNeeded: nil]);
}

- (void) testConnect2
{
	NSURL* uri = [self databaseURI];
	NSString* uriString = [uri absoluteString];
	uriString = [uriString stringByAppendingString: @"/"];
	uri = [NSURL URLWithString: uriString];
	
    MKCAssertNoThrow ([ctx setDatabaseURI: uri]);
    MKCAssertNoThrow ([ctx connectIfNeeded: nil]);
}
 
- (void) testConnectFail1
{
    MKCAssertNoThrow ([ctx setDatabaseURI: [NSURL URLWithString: @"pgsql://localhost/anonexistantdatabase"]]);
    MKCAssertThrows ([ctx connectIfNeeded: nil]);
}
 
- (void) testConnectFail2
{
    MKCAssertNoThrow ([ctx setDatabaseURI: 
        [NSURL URLWithString: @"pgsql://user@localhost/basetentest/a/malformed/database/uri"]]);
    MKCAssertThrows ([ctx connectIfNeeded: nil]);
}

- (void) testConnectFail3
{
    MKCAssertThrows ([ctx setDatabaseURI: [NSURL URLWithString: @"invalid://user@localhost/invalid"]]);
}

- (void) testNilURI
{
	NSError* error = nil;
	id rval = nil;
	BXEntityDescription* entity = [ctx entityForTable: @"test" error: &error];
	rval = [ctx executeFetchForEntity: entity withPredicate: nil error: &error];
	MKCAssertNotNil (error);
	rval = [ctx createObjectForEntity: entity withFieldValues: nil error: &error];
	MKCAssertNotNil (error);
}

- (void) testConnectFail4
{
	[ctx setDatabaseURI: [NSURL URLWithString: @"pgsql://localhost/anonexistantdatabase"]];
	[[ctx notificationCenter] addObserver: self selector: @selector (expected:) name: kBXConnectionFailedNotification object: nil];
	[[ctx notificationCenter] addObserver: self selector: @selector (unexpected:) name: kBXConnectionSuccessfulNotification object: nil];
	[ctx connectAsync];
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 2.0]];
	[ctx connectAsync];
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 2.0]];
	[ctx connectAsync];
	[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 2.0]];
	STAssertTrue (3 == expectedCount, @"Expected 3 connection attempts while there were %d.", expectedCount);
}

- (void) expected: (NSNotification *) n
{
	expectedCount++;
}

- (void) unexpected: (NSNotification *) n
{
	STAssertTrue (NO, @"Expected connection not to have been made.");
}

@end
