//
// BXMetadataTests.m
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

#import "BXMetadataTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXPGInterface.h>
#import <BaseTen/BXPGDatabaseDescription.h>
#import <BaseTen/PGTSConnection.h>
#import <BaseTen/PGTSTableDescription.h>
#import <BaseTen/PGTSIndexDescription.h>



@implementation BXMetadataTests
- (void) setUp
{
	[super setUp];
	
	[BXPGInterface class]; // Run +initialize.
	
	NSDictionary* connectionDictionary = [self connectionDictionary];
	PGTSConnection* connection = [[[PGTSConnection alloc] init] autorelease];
	BOOL status = [connection connectSync: connectionDictionary];
	STAssertTrue (status, [[connection connectionError] description]);
	
	mDatabaseDescription = (id) [[connection databaseDescription] retain];
	MKCAssertEqualObjects ([mDatabaseDescription class], [BXPGDatabaseDescription class]);
	
	[connection disconnect];
}


- (void) tearDown
{
	[mDatabaseDescription release];
	[super tearDown];
}


- (void) test0SchemaVersion
{
	NSNumber *currentVersion = [BXPGVersion currentVersionNumber];
	NSNumber *currentCompatVersion = [BXPGVersion currentCompatibilityVersionNumber];
	
	MKCAssertEqualObjects (currentCompatVersion, [mDatabaseDescription schemaCompatibilityVersion]);
	MKCAssertEqualObjects (currentVersion, [mDatabaseDescription schemaVersion]);
}


- (void) test1ViewPkey
{
	MKCAssertNotNil (mDatabaseDescription);
	PGTSTableDescription* table = [mDatabaseDescription table: @"test_v" inSchema: @"public"];
	MKCAssertNotNil (table);
	PGTSIndexDescription* pkey = [table primaryKey];
	
	MKCAssertNotNil (pkey);
	MKCAssertFalse ([pkey isUnique]);
	MKCAssertTrue ([pkey isPrimaryKey]);
	
	NSSet* columns = [pkey columns];
	MKCAssertTrue (1 == [columns count]);
	
	MKCAssertEqualObjects (@"id", [[columns anyObject] name]);	
}
@end
