//
// PredicateTests.m
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

#import "PredicateTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXPGInterface.h>
#import <BaseTen/BXPGQueryBuilder.h>
#import <BaseTen/BXPredicateVisitor.h>


@implementation PredicateTests
- (void) setUp
{
	mQueryBuilder = [[BXPGQueryBuilder alloc] init];
	
	BXDatabaseContext* ctx = [[BXDatabaseContext contextWithDatabaseURI: 
							   [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]] retain];
	BXEntityDescription* entity = [ctx entityForTable: @"test" inSchema: @"public" error: NULL];
	[mQueryBuilder addPrimaryRelationForEntity: entity];
	
	BXPGInterface* interface = (id)[ctx databaseInterface];
	[interface prepareForConnecting];
	BXPGTransactionHandler* handler = (id)[interface transactionHandler];
	[handler prepareForConnecting];
	mConnection = [[handler connection] retain];
}

- (void) tearDown
{
	[mQueryBuilder release];
	[mConnection release];
}

- (void) testAddition
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"1 + 2 == 3"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"$1 = ($2 + $3)");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects: [NSNumber numberWithInt: 3], [NSNumber numberWithInt: 1], [NSNumber numberWithInt: 2], nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testSubtraction
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"3 - 2 == 1"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"$1 = ($2 - $3)");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects: [NSNumber numberWithInt: 1], [NSNumber numberWithInt: 3], [NSNumber numberWithInt: 2], nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testBegins
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"'foobar' BEGINSWITH 'foo'"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"$1 ~~ (regexp_replace ($2, '([%_\\\\])', '\\\\\\1', 'g') || '%')");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects: @"foobar", @"foo", nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testEndsCase
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"'foobar' ENDSWITH[c] 'b%a_r'"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"$1 ~~* ('%' || regexp_replace ($2, '([%_\\\\])', '\\\\\\1', 'g'))");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects: @"foobar", @"b%a_r", nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testBetween
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"2 BETWEEN {1, 3}"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"ARRAY [$1,$2] OPERATOR (\"baseten\".<<>>) $3");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects:
						 [NSNumber numberWithInt: 1],
						 [NSNumber numberWithInt: 3],
						 [NSNumber numberWithInt: 2],
						 nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testGt
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"1 < 2"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"$1 > $2");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects:
						 [NSNumber numberWithInt: 2],
						 [NSNumber numberWithInt: 1],
						 nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testContains
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"{1, 2, 3} CONTAINS 2"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"$1 = ANY (ARRAY [$2,$3,$4])");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects:
						 [NSNumber numberWithInt: 2],
						 [NSNumber numberWithInt: 1],
						 [NSNumber numberWithInt: 2],
						 [NSNumber numberWithInt: 3],
						 nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testIn
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"2 IN {1, 2, 3}"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"$1 = ANY (ARRAY [$2,$3,$4])");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects:
						 [NSNumber numberWithInt: 2],
						 [NSNumber numberWithInt: 1],
						 [NSNumber numberWithInt: 2],
						 [NSNumber numberWithInt: 3],
						 nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testIn2
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"'bb' IN 'aabbccdd'"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"(0 != position ($1 in $2))");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects: @"bb", @"aabbccdd", nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testIn3
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"'bb' IN[c] 'aabbccdd'"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"$1 ~~* ('%' || regexp_replace ($2, '([%_\\\\])', '\\\\\\1', 'g') || '%')");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects: @"aabbccdd", @"bb", nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testAndOr
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"1 < 2 AND (2 < 3 OR 4 > 5)"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"($1 > $2 AND ($3 > $4 OR $5 < $6))");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects:
						 [NSNumber numberWithInt: 2],
						 [NSNumber numberWithInt: 1],
						 [NSNumber numberWithInt: 3],
						 [NSNumber numberWithInt: 2],
						 [NSNumber numberWithInt: 5],
						 [NSNumber numberWithInt: 4],
						 nil];
	MKCAssertEqualObjects (parameters, expected);
}

- (void) testNull
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"1 == %@", [NSNull null]];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection].p_where_clause;
	MKCAssertEqualObjects (whereClause, @"$1 IS NULL");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObject: [NSNumber numberWithInt: 1]];
	MKCAssertEqualObjects (parameters, expected);
}

//We need a validated entity for this test.
#if 0
- (void) testAdditionWithKeyPath
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"1 + id == 2"];
	NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: nil connection: mConnection];
	MKCAssertEqualObjects (whereClause, @"$1 = ($2 + $3)");
	NSArray* parameters = [mQueryBuilder parameters];
	NSArray* expected = [NSArray arrayWithObjects: [NSNumber numberWithInt: 3], [NSNumber numberWithInt: 1], [NSNumber numberWithInt: 2], nil];
	MKCAssertEqualObjects (parameters, expected);	
}
#endif


@end
