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
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXDataModelCompiler.h>
#import <BaseTen/BXPGInterface.h>
#import <BaseTen/BXPGTransactionHandler.h>
#import <BaseTen/BXEnumerate.h>
#import "MKCSenTestCaseAdditions.h"


@implementation BXDataModelTests
- (void) setUp
{
	[super setUp];
	
	mConverter = [[BXPGEntityConverter alloc] init];
	[mConverter setDelegate: self];
}


- (void) tearDown
{
	[mConverter release];
	[super tearDown];
}


- (BXEntityDescription *) entityConverter: (BXPGEntityConverter *) converter 
 shouldAddDropStatementFromEntityMatching: (NSEntityDescription *) importedEntity
								 inSchema: (NSString *) schemaName
									error: (NSError **) outError
{
	return NO;
}


- (BOOL) entityConverter: (BXPGEntityConverter *) converter shouldCreateSchema: (NSString *) schemaName
{
	return YES;
}


- (PGTSConnection *) connectionForEntityConverter: (BXPGEntityConverter *) converter
{
	return [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];
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
	
	NSArray *enabledRelations = nil;
	NSArray *errors = nil;
	NSArray *statements = [mConverter statementsForEntities: entities
												 schemaName: @"test_schema"
										   enabledRelations: &enabledRelations 
													 errors: &errors];
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
						 @"CREATE TABLE \"test_schema\".\"Employee\" (id SERIAL, \"room\" smallint , \"salary\" numeric ) INHERITS (\"test_schema\".\"Person\");",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ADD PRIMARY KEY (id);",
						 @"CREATE TABLE \"test_schema\".\"Department\" (id SERIAL) ;",
						 @"ALTER TABLE \"test_schema\".\"Department\" ADD PRIMARY KEY (id);",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ADD COLUMN \"department_id\" integer;",
						 @"ALTER TABLE \"test_schema\".\"Employee\" ADD CONSTRAINT \"department__employee\"   FOREIGN KEY (\"department_id\") REFERENCES \"test_schema\".\"Department\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						 nil];
	MKCAssertEqualObjects (expected, statements);
}


- (void) testPeopleDepartmentsNoInverse
{
	NSArray* statements = [self importStatements: @"people-departments-no-inverse"];
	NSArray* expected  = [NSArray arrayWithObjects:
						  @"CREATE SCHEMA \"test_schema\";",
						  @"CREATE TABLE \"test_schema\".\"Employee\" (id SERIAL, \"room\" smallint , \"salary\" numeric ) ;",
						  @"ALTER TABLE \"test_schema\".\"Employee\" ADD PRIMARY KEY (id);",
						  @"CREATE TABLE \"test_schema\".\"Department\" (id SERIAL) ;",
						  @"ALTER TABLE \"test_schema\".\"Department\" ADD PRIMARY KEY (id);",
						  @"ALTER TABLE \"test_schema\".\"Employee\" ADD COLUMN \"department_id\" integer;",
						  @"ALTER TABLE \"test_schema\".\"Employee\" ADD CONSTRAINT \"department\"   FOREIGN KEY (\"department_id\") REFERENCES \"test_schema\".\"Department\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						  nil];
	MKCAssertEqualObjects (expected, statements);
}	


- (void) testOneToOne
{
	NSArray* statements = [self importStatements: @"one-to-one"];
	NSArray* expected1 = [NSArray arrayWithObjects:
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
	NSArray* expected2 = [NSArray arrayWithObjects:
						  @"CREATE SCHEMA \"test_schema\";",
						  @"CREATE TABLE \"test_schema\".\"d\" (id SERIAL) ;",
						  @"ALTER TABLE \"test_schema\".\"d\" ADD PRIMARY KEY (id);",
						  @"CREATE TABLE \"test_schema\".\"b\" (id SERIAL) ;",
						  @"ALTER TABLE \"test_schema\".\"b\" ADD PRIMARY KEY (id);",
						  @"CREATE TABLE \"test_schema\".\"c\" (id SERIAL) ;",
						  @"ALTER TABLE \"test_schema\".\"c\" ADD PRIMARY KEY (id);",
						  @"CREATE TABLE \"test_schema\".\"a\" (id SERIAL) ;",
						  @"ALTER TABLE \"test_schema\".\"a\" ADD PRIMARY KEY (id);",
						  @"ALTER TABLE \"test_schema\".\"d\" ADD COLUMN \"dc_id\" integer;",
						  @"ALTER TABLE \"test_schema\".\"d\" ADD UNIQUE (\"dc_id\");",
						  @"ALTER TABLE \"test_schema\".\"d\" ADD CONSTRAINT \"dc__cd\"   FOREIGN KEY (\"dc_id\") REFERENCES \"test_schema\".\"c\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						  @"ALTER TABLE \"test_schema\".\"b\" ADD COLUMN \"ba_id\" integer;",
						  @"ALTER TABLE \"test_schema\".\"b\" ALTER COLUMN \"ba_id\" SET NOT NULL;",
						  @"ALTER TABLE \"test_schema\".\"b\" ADD UNIQUE (\"ba_id\");",
						  @"ALTER TABLE \"test_schema\".\"b\" ADD CONSTRAINT \"ba__ab\"   FOREIGN KEY (\"ba_id\") REFERENCES \"test_schema\".\"a\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
						  nil];
						  
	STAssertTrue ([expected1 isEqual: statements] || [expected2 isEqual: statements],
				  @"Expected statements to equal one of the following."
				  @"statements: %@\nexpected1: %@\nexpected2: %@",
				  statements, expected1, expected2);
}


- (void) testRelationshipOptionality
{
	NSArray* statements = [self importStatements: @"relationship-optionality"];
	MKCAssertTrue (38 == [statements count]);
	NSArray* creationStatements = [statements subarrayWithRange: NSMakeRange (1, 20)];
	NSArray* constraintStatements = [statements subarrayWithRange: NSMakeRange (21, 17)];
	
	MKCAssertEqualObjects ([statements objectAtIndex: 0], @"CREATE SCHEMA \"test_schema\";");
	
	{
		NSArray* expectedCreationStatements = [NSArray arrayWithObjects:
											   @"CREATE TABLE \"test_schema\".\"Author\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"Author\" ADD PRIMARY KEY (id);",
											   @"CREATE TABLE \"test_schema\".\"Book\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"Book\" ADD PRIMARY KEY (id);",
											   @"CREATE TABLE \"test_schema\".\"Date\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"Date\" ADD PRIMARY KEY (id);",
											   @"CREATE TABLE \"test_schema\".\"Department\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"Department\" ADD PRIMARY KEY (id);",
											   @"CREATE TABLE \"test_schema\".\"Employee\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"Employee\" ADD PRIMARY KEY (id);",
											   @"CREATE TABLE \"test_schema\".\"Licence\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"Licence\" ADD PRIMARY KEY (id);",
											   @"CREATE TABLE \"test_schema\".\"Location\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"Location\" ADD PRIMARY KEY (id);",
											   @"CREATE TABLE \"test_schema\".\"Person\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"Person\" ADD PRIMARY KEY (id);",
											   @"CREATE TABLE \"test_schema\".\"Revision\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"Revision\" ADD PRIMARY KEY (id);",
											   @"CREATE TABLE \"test_schema\".\"User\" (id SERIAL) ;",
											   @"ALTER TABLE \"test_schema\".\"User\" ADD PRIMARY KEY (id);",
											   nil];
		STAssertTrue (0 == [expectedCreationStatements count] % 2, 
					  @"There should be an equal number of expected creation statements in the test.");
		
		NSEnumerator* e = [expectedCreationStatements objectEnumerator];
		NSString* stmt = nil;
		while ((stmt = [e nextObject]))
		{
			NSUInteger i = [creationStatements indexOfObject: stmt];
			MKCAssertFalse (NSNotFound == i);
			
			stmt = [e nextObject];
			NSUInteger j = [creationStatements indexOfObject: stmt];
			MKCAssertFalse (NSNotFound == j);
			MKCAssertTrue (i + 1 == j);
		}
	}
	
	{
		NSArray* constraintStmtArrays = [NSArray arrayWithObjects:
										 [NSArray arrayWithObjects:
										  @"ALTER TABLE \"test_schema\".\"Employee\" ADD COLUMN \"department_id\" integer;",
										  @"ALTER TABLE \"test_schema\".\"Employee\" ALTER COLUMN \"department_id\" SET NOT NULL;",
										  @"ALTER TABLE \"test_schema\".\"Employee\" ADD CONSTRAINT \"department__people\"   FOREIGN KEY (\"department_id\") REFERENCES \"test_schema\".\"Department\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
										  nil],
										 [NSArray arrayWithObjects:
										  @"ALTER TABLE \"test_schema\".\"Person\" ADD COLUMN \"address_id\" integer;",
										  @"ALTER TABLE \"test_schema\".\"Person\" ADD CONSTRAINT \"address__people\"   FOREIGN KEY (\"address_id\") REFERENCES \"test_schema\".\"Location\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
										  nil],
										 [NSArray arrayWithObjects:
										  @"ALTER TABLE \"test_schema\".\"Revision\" ADD COLUMN \"date_id\" integer;",
										  @"ALTER TABLE \"test_schema\".\"Revision\" ALTER COLUMN \"date_id\" SET NOT NULL;",
										  @"ALTER TABLE \"test_schema\".\"Revision\" ADD UNIQUE (\"date_id\");",
										  @"ALTER TABLE \"test_schema\".\"Revision\" ADD CONSTRAINT \"date__revision\"   FOREIGN KEY (\"date_id\") REFERENCES \"test_schema\".\"Date\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
										  nil],										 
										 nil];
		BXEnumerate (expectedConstraintStmts, e, [constraintStmtArrays objectEnumerator])
		{
			NSString* addColStmt = [expectedConstraintStmts objectAtIndex: 0];
			NSUInteger addColIdx = [constraintStatements indexOfObject: addColStmt];
			MKCAssertFalse (NSNotFound == addColIdx);
			
			NSEnumerator* e = [expectedConstraintStmts objectEnumerator];
			[e nextObject];
			NSString* stmt = nil;
			while ((stmt = [e nextObject]))
			{
				NSUInteger idx = [constraintStatements indexOfObject: stmt];
				MKCAssertFalse (NSNotFound == idx);
				MKCAssertTrue (addColIdx < idx);
			}
		}
	}
	
	{
		NSArray* uniqueConstraintStmtArrays = [NSArray arrayWithObjects:
											   [NSArray arrayWithObjects:
												@"ALTER TABLE \"test_schema\".\"User\" ADD COLUMN \"licence_id\" integer;",
												@"ALTER TABLE \"test_schema\".\"User\" ADD UNIQUE (\"licence_id\");",
												@"ALTER TABLE \"test_schema\".\"User\" ADD CONSTRAINT \"licence__user\"   FOREIGN KEY (\"licence_id\") REFERENCES \"test_schema\".\"Licence\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
												nil],
											   [NSArray arrayWithObjects:
												@"ALTER TABLE \"test_schema\".\"Licence\" ADD COLUMN \"user_id\" integer;",
												@"ALTER TABLE \"test_schema\".\"Licence\" ADD UNIQUE (\"user_id\");",
												@"ALTER TABLE \"test_schema\".\"Licence\" ADD CONSTRAINT \"user__licence\"   FOREIGN KEY (\"user_id\") REFERENCES \"test_schema\".\"User\" (id)   ON DELETE SET NULL ON UPDATE CASCADE;",
												nil],
											   nil];
		BOOL ok = NO;
		BXEnumerate (expectedConstraintStmts, e, [uniqueConstraintStmtArrays objectEnumerator])
		{
			NSString* addColStmt = [expectedConstraintStmts objectAtIndex: 0];
			NSUInteger addColIdx = [constraintStatements indexOfObject: addColStmt];
			if (NSNotFound == addColIdx)
				continue;
			
			NSEnumerator* e = [expectedConstraintStmts objectEnumerator];
			[e nextObject];
			NSString* stmt = nil;
			while ((stmt = [e nextObject]))
			{
				NSUInteger idx = [constraintStatements indexOfObject: stmt];
				if (NSNotFound == idx || ! (addColIdx < idx))
					goto loopend;
			}
			
			ok = YES;
			break;
			
		loopend:
			;
		}
		MKCAssertTrue (ok);
	}
	
	{
		NSArray* expectedMTMStmts = [NSArray arrayWithObjects:
									 @"DROP TABLE IF EXISTS \"test_schema\".\"authors_books_rel\" CASCADE;",
									 @"CREATE TABLE \"test_schema\".\"authors_books_rel\" (\"Author_id\" integer, \"Book_id\" integer);",
									 @"ALTER TABLE \"test_schema\".\"authors_books_rel\" ADD PRIMARY KEY (\"Author_id\", \"Book_id\")",
									 @"ALTER TABLE \"test_schema\".\"authors_books_rel\" ADD CONSTRAINT \"authors\"   FOREIGN KEY (\"Book_id\") REFERENCES \"test_schema\".\"Book\" (id)   ON UPDATE CASCADE ON DELETE CASCADE;",
									 @"ALTER TABLE \"test_schema\".\"authors_books_rel\" ADD CONSTRAINT \"books\"   FOREIGN KEY (\"Author_id\") REFERENCES \"test_schema\".\"Author\" (id)   ON UPDATE CASCADE ON DELETE CASCADE;",
									 nil];
		NSUInteger i = [constraintStatements indexOfObject: [expectedMTMStmts objectAtIndex: 0]];
		NSUInteger j = [constraintStatements indexOfObject: [expectedMTMStmts objectAtIndex: 1]];
		MKCAssertFalse (NSNotFound == i);
		MKCAssertFalse (NSNotFound == j);
		MKCAssertTrue (i + 1 == j);
		
		NSEnumerator* e = [expectedMTMStmts objectEnumerator];
		[e nextObject];
		[e nextObject];
		NSString* stmt = nil;
		while ((stmt = [e nextObject]))
		{
			NSUInteger idx = [constraintStatements indexOfObject: stmt];
			MKCAssertFalse (NSNotFound == idx);
			MKCAssertTrue (j < idx);
		}
	}
}
@end
