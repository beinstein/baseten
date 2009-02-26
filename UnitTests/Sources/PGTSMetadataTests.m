//
// PGTSMetadataTests.m
// BaseTen
//
// Copyright (C) 2009 Marko Karppinen & Co. LLC.
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

#import "PGTSMetadataTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/PGTSConnection.h>
#import <BaseTen/PGTSDatabaseDescription.h>
#import <BaseTen/PGTSSchemaDescription.h>
#import <BaseTen/PGTSTableDescription.h>
#import <BaseTen/PGTSColumnDescription.h>
#import <BaseTen/PGTSIndexDescription.h>
#import <BaseTen/PGTSTypeDescription.h>
#import <BaseTen/BXEnumerate.h>


@implementation PGTSMetadataTests
- (void) setUp
{
	[super setUp];
	NSString* connectionString = @"host = 'localhost' user = 'baseten_test_user' dbname = 'basetentest'";
	PGTSConnection* connection = [[[PGTSConnection alloc] init] autorelease];
	BOOL status = [connection connectSync: connectionString];
	STAssertTrue (status, [[[connection connectionError] userInfo] description]);
	mDatabaseDescription = [[connection databaseDescription] retain];
	[connection disconnect];
}

- (void) tearDown
{
	[mDatabaseDescription release];
	[super tearDown];
}

- (void) test1Table
{
	MKCAssertNotNil (mDatabaseDescription);
	PGTSTableDescription* table = [mDatabaseDescription table: @"test" inSchema: @"public"];
	MKCAssertNotNil (table);
	MKCAssertEqualObjects (@"test", [table name]);
	MKCAssertEqualObjects (@"public", [[table schema] name]);
}

- (void) test2Columns
{
	MKCAssertNotNil (mDatabaseDescription);
	PGTSTableDescription* table = [mDatabaseDescription table: @"test" inSchema: @"public"];
	MKCAssertNotNil (table);
	NSDictionary* columns = [table columns];
	
	int count = 0;
	BXEnumerate (currentColumn, e, [columns objectEnumerator])
	{
		NSInteger idx = [currentColumn index];
		if (0 < idx)
			count++;
	}
	MKCAssertTrue (2 == count);
	
	{
		PGTSColumnDescription* column = [columns objectForKey: @"id"];
		MKCAssertNotNil (column);
		MKCAssertTrue (1 == [column index]);
		MKCAssertTrue (YES == [column isNotNull]);
		MKCAssertEqualObjects (@"nextval('test_id_seq'::regclass)", [column defaultValue]);
		
		PGTSTypeDescription* type = [column type];
		MKCAssertEqualObjects (@"int4", [type name]);
	}
	
	{
		PGTSColumnDescription* column = [columns objectForKey: @"value"];
		MKCAssertNotNil (column);
		MKCAssertTrue (2 == [column index]);
		MKCAssertTrue (NO == [column isNotNull]);
		MKCAssertNil ([column defaultValue]);
		
		PGTSTypeDescription* type = [column type];
		MKCAssertEqualObjects (@"varchar", [type name]);
	}	
}

- (void) test3Pkey
{
	MKCAssertNotNil (mDatabaseDescription);
	PGTSTableDescription* table = [mDatabaseDescription table: @"test" inSchema: @"public"];
	MKCAssertNotNil (table);
	PGTSIndexDescription* pkey = [table primaryKey];
	
	MKCAssertFalse ([pkey isUnique]);
	MKCAssertTrue ([pkey isPrimaryKey]);
	
	NSSet* columns = [pkey columns];
	MKCAssertTrue (1 == [columns count]);
	
	MKCAssertEqualObjects (@"id", [[columns anyObject] name]);
}

- (void) test4ViewPkey
{
	MKCAssertNotNil (mDatabaseDescription);
	PGTSTableDescription* table = [mDatabaseDescription table: @"test_v" inSchema: @"public"];
	MKCAssertNotNil (table);
	PGTSIndexDescription* pkey = [table primaryKey];
	
	MKCAssertFalse ([pkey isUnique]);
	MKCAssertTrue ([pkey isPrimaryKey]);
	
	NSSet* columns = [pkey columns];
	MKCAssertTrue (1 == [columns count]);
	
	MKCAssertEqualObjects (@"id", [[columns anyObject] name]);	
}
@end
