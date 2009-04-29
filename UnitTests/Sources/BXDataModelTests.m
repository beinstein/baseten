//
// BXDataModelTests.m
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

#import "BXDataModelTests.h"
#import <BaseTen/BXDataModelCompiler.h>
#import <BaseTen/BXPGEntityConverter.h>
#import "MKCSenTestCaseAdditions.h"


@implementation BXDataModelTests
- (void) setUp
{
	mImporter = [[BXPGEntityImporter alloc] init];
	mContext = [[BXDatabaseContext alloc] initWithDatabaseURI: [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
	
	[mImporter setDelegate: self];
	[mImporter setDatabaseContext: mContext];
}

- (void) tearDown
{
	[mImporter release];
	[mContext release];
}

- (void) entityImporterAdvanced: (BXPGEntityImporter *) importer
{
}

- (void) entityImporter: (BXPGEntityImporter *) importer finishedImporting: (BOOL) succeeded error: (NSError *) error
{
}

- (void) testPeopleDepartments
{
	NSBundle* bundle = [NSBundle bundleForClass: [self class]];
	NSString* path = [bundle pathForResource: @"people-departments" ofType: @"mom"];
	NSURL* url = [NSURL fileURLWithPath: path];
	MKCAssertNotNil (bundle);
	MKCAssertNotNil (path);
	MKCAssertNotNil (url);
		
	NSManagedObjectModel* model = [[[NSManagedObjectModel alloc] initWithContentsOfURL: url] autorelease];
	NSArray* entities = [model entities];
	MKCAssertNotNil (model);
	MKCAssertNotNil (entities);
	
	[mImporter setSchemaName: @"test_schema"];
	[mImporter setEntities: entities];
	NSArray* statements = [mImporter importStatements];
	
	NSArray* expected = [NSArray arrayWithObjects:
						 @"CREATE SCHEMA \"test_schema\";",
						 @"CREATE TABLE \"test_schema\".\"Person\" (id SERIAL, \"surname\" text , \"birthday\" timestamp with time zone ) ;",
						 @"ALTER TABLE \"test_schema\".\"Person\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Employee\" (id SERIAL, \"salary\" numeric , \"room\" smallint ) INHERITS (\"test_schema\".\"Person\");",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Department\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Department\" ADD PRIMARY KEY (id);",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ADD COLUMN \"department_id\" integer;",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ADD CONSTRAINT \"department__employee\"   FOREIGN KEY (\"department_id\") REFERENCES \"test_schema\".\"Department\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						 nil];
	MKCAssertEqualObjects (expected, statements);
}
@end
