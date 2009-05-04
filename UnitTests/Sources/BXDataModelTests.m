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
	[super setUp];
	
	mImporter = [[BXPGEntityImporter alloc] init];
	[mImporter setDelegate: self];
	[mImporter setDatabaseContext: mContext];
}

- (void) tearDown
{
	[mImporter release];
	[super tearDown];
}

- (void) entityImporterAdvanced: (BXPGEntityImporter *) importer
{
}

- (void) entityImporter: (BXPGEntityImporter *) importer finishedImporting: (BOOL) succeeded error: (NSError *) error
{
}


- (NSArray *) importStatements: (NSString *) modelFile
{
	NSBundle* bundle = [NSBundle bundleForClass: [self class]];
	NSString* path = [bundle pathForResource: modelFile ofType: @"mom"];
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
	MKCAssertNotNil (statements);
	
	return statements;
}

- (void) testPeopleDepartments
{
	NSArray* statements = [self importStatements: @"people-departments"];
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

- (void) testOneToOne
{
	NSArray* statements = [self importStatements: @"one-to-one"];
	NSArray* expected = [NSArray arrayWithObjects:
						 @"CREATE SCHEMA \"test_schema\";",
						 @"CREATE TABLE \"test_schema\".\"a\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"a\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"b\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"b\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"c\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"c\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"d\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"d\" ADD PRIMARY KEY (id);",
						 @"ALTER TABLE \"test_schema\".\"a\" ADD COLUMN \"ab_id\" integer;",
						 @"ALTER TABLE \"test_schema\".\"a\" ALTER COLUMN \"ab_id\" SET NOT NULL;",
						 @"ALTER TABLE \"test_schema\".\"a\" ADD UNIQUE (\"ab_id\");",
						 @"ALTER TABLE \"test_schema\".\"a\" ADD CONSTRAINT \"ab__ba\"   FOREIGN KEY (\"ab_id\") REFERENCES \"test_schema\".\"b\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						 @"ALTER TABLE \"test_schema\".\"c\" ADD COLUMN \"cd_id\" integer;",
						 @"ALTER TABLE \"test_schema\".\"c\" ADD UNIQUE (\"cd_id\");",
						 @"ALTER TABLE \"test_schema\".\"c\" ADD CONSTRAINT \"cd__dc\"   FOREIGN KEY (\"cd_id\") REFERENCES \"test_schema\".\"d\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						 nil];
	MKCAssertEqualObjects (expected, statements);
}

- (void) testRelationshipOptionality
{
	NSArray* statements = [self importStatements: @"relationship-optionality"];
	NSArray* expected = [NSArray arrayWithObjects:
						 @"CREATE SCHEMA \"test_schema\";",
						 @"CREATE TABLE \"test_schema\".\"Book\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Book\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"User\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"User\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Department\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Department\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Location\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Location\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Revision\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Revision\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Date\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Date\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Employee\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Author\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Author\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Licence\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Licence\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Person\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Person\" ADD PRIMARY KEY (id);",
						 @"DROP TABLE IF EXISTS \"test_schema\".\"authors_books_rel\" CASCADE;",
						 @"CREATE TABLE \"test_schema\".\"authors_books_rel\" (\"Book_id\" integer, \"Author_id\" integer);",
						 @"ALTER TABLE \"test_schema\".\"authors_books_rel\" ADD PRIMARY KEY (\"Book_id\", \"Author_id\")",
						 @"ALTER TABLE \"test_schema\".\"authors_books_rel\" ADD CONSTRAINT \"authors\"   FOREIGN KEY (\"Book_id\") REFERENCES \"test_schema\".\"Book\" (id)   ON UPDATE CASCADE ON DELETE CASCADE;",
						 @"ALTER TABLE \"test_schema\".\"authors_books_rel\" ADD CONSTRAINT \"books\"   FOREIGN KEY (\"Author_id\") REFERENCES \"test_schema\".\"Author\" (id)   ON UPDATE CASCADE ON DELETE CASCADE;",
						 @"ALTER TABLE \"test_schema\".\"User\" ADD COLUMN \"licence_id\" integer;",
						 @"ALTER TABLE \"test_schema\".\"User\" ADD UNIQUE (\"licence_id\");",
						 @"ALTER TABLE \"test_schema\".\"User\" ADD CONSTRAINT \"licence__user\"   FOREIGN KEY (\"licence_id\") REFERENCES \"test_schema\".\"Licence\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ADD COLUMN \"department_id\" integer;",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ALTER COLUMN \"department_id\" SET NOT NULL;",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ADD CONSTRAINT \"department__people\"   FOREIGN KEY (\"department_id\") REFERENCES \"test_schema\".\"Department\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						 @"ALTER TABLE \"test_schema\".\"Person\" ADD COLUMN \"address_id\" integer;",
						 @"ALTER TABLE \"test_schema\".\"Person\" ADD CONSTRAINT \"address__people\"   FOREIGN KEY (\"address_id\") REFERENCES \"test_schema\".\"Location\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						 @"ALTER TABLE \"test_schema\".\"Revision\" ADD COLUMN \"date_id\" integer;",
						 @"ALTER TABLE \"test_schema\".\"Revision\" ALTER COLUMN \"date_id\" SET NOT NULL;",
						 @"ALTER TABLE \"test_schema\".\"Revision\" ADD UNIQUE (\"date_id\");",
						 @"ALTER TABLE \"test_schema\".\"Revision\" ADD CONSTRAINT \"date__revision\"   FOREIGN KEY (\"date_id\") REFERENCES \"test_schema\".\"Date\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						 nil];
	MKCAssertEqualObjects (expected, statements);
}
@end
