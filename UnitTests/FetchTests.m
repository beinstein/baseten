//
// FetchTests.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
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

#import "FetchTests.h"
#import "MKCSenTestCaseAdditions.h"

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseObjectIDPrivate.h>
#import <BaseTen/BXDatabaseAdditions.h>
#import <BaseTen/BXEntityDescriptionPrivate.h>


@interface BXDatabaseObject (BXKVC)
- (id) id1;
- (id) id2;
- (id) value1;
@end


@interface FetchTestObject : BXDatabaseObject
{
	@public
	BOOL didTurnIntoFault;
}
@end


@implementation FetchTestObject
- (void) didTurnIntoFault
{
	didTurnIntoFault = YES;
}
@end


@implementation FetchTests

- (void) setUp
{
    context = [[BXDatabaseContext alloc] initWithDatabaseURI: 
        [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
	[context setAutocommits: NO];
	NSError* error = nil;
    entity = [context entityForTable: @"test" error: &error];
	STAssertNil (error, [error localizedDescription]);
    MKCAssertNotNil (entity);
}

- (void) tearDown
{
    [context release];
}

- (void) testObjectWithID
{
    NSError* error = nil;
	NSURL* objectURI = [NSURL URLWithString: @"pgsql://localhost/basetentest/public/test?id,n=1"];
	BXDatabaseObjectID* anId = [[[BXDatabaseObjectID alloc] initWithURI: objectURI
																context: context 
																  error: &error] autorelease];
	STAssertNil (error, [error localizedDescription]);
    BXDatabaseObject* object = [context objectWithID: anId error: &error];
	STAssertNil (error, [error localizedDescription]);
    MKCAssertEqualObjects ([object primitiveValueForKey: @"id"], [NSNumber numberWithInt: 1]);
    //if this is not nil, then another test has failed or the database is not in known state
    STAssertEqualObjects ([object valueForKey: @"value"], nil, @"Database is not in known state!");
}

- (void) testMultiColumnPkey
{
    NSError* error = nil;
    [context connectIfNeeded: nil];
    
    BXEntityDescription* multicolumnpkey = [context entityForTable: @"multicolumnpkey" error: nil];
    MKCAssertNotNil (multicolumnpkey);
    NSArray* multicolumnpkeys = [context executeFetchForEntity: multicolumnpkey withPredicate: nil error: &error];
    MKCAssertNotNil (multicolumnpkeys);
    MKCAssertTrue (3 == [multicolumnpkeys  count]);
    STAssertNil (error, @"Error: %@", error);
    
    NSSortDescriptor* s1 = [[[NSSortDescriptor alloc] initWithKey: @"id1" ascending: YES] autorelease];
    NSSortDescriptor* s2 = [[[NSSortDescriptor alloc] initWithKey: @"id2" ascending: YES] autorelease];
    multicolumnpkeys = [multicolumnpkeys sortedArrayUsingDescriptors: [NSArray arrayWithObjects: s1, s2, nil]];
    
    id r1 = [multicolumnpkeys objectAtIndex: 0];
    id r2 = [multicolumnpkeys objectAtIndex: 1];
    id r3 = [multicolumnpkeys objectAtIndex: 2];
    
    NSNumber* id1 = [r1 id1];
    MKCAssertEqualObjects (id1, [NSNumber numberWithInt: 1]);
    MKCAssertEqualObjects ([r1 id2], [NSNumber numberWithInt: 1]);
    MKCAssertEqualObjects ([r1 value1], @"thevalue1");
    MKCAssertEqualObjects ([r2 id1], [NSNumber numberWithInt: 1]);
    MKCAssertEqualObjects ([r2 id2], [NSNumber numberWithInt: 2]);
    MKCAssertEqualObjects ([r2 value1], @"thevalue2");
    MKCAssertEqualObjects ([r3 id1], [NSNumber numberWithInt: 2]);
    MKCAssertEqualObjects ([r3 id2], [NSNumber numberWithInt: 3]);
    MKCAssertEqualObjects ([r3 value1], @"thevalue3");
}

- (void) testDates
{
    NSError* error = nil;
    [context connectIfNeeded: nil];
    
    BXEntityDescription* datetest = [context entityForTable: @"datetest" error: nil];
    MKCAssertNotNil (datetest);
    NSArray* dateobjects = [context executeFetchForEntity: datetest withPredicate: nil error: &error];
    STAssertNil (error, [error localizedDescription]);
    MKCAssertNotNil (dateobjects);
}

- (void) testQuery
{
	NSError* error = nil;
	NSArray* result = [context executeQuery: [NSString stringWithUTF8String: "SELECT * FROM ♨"] error: &error];
	STAssertNil (error, [error localizedDescription]);
	MKCAssertTrue (3 == [result count]);
	TSEnumerate (currentRow, e, [result objectEnumerator])
		MKCAssertTrue (2 == [currentRow count]);
}

- (void) testCommand
{
	NSError* error = nil;
	unsigned long long count = [context executeCommand: [NSString stringWithUTF8String: "UPDATE ♨ SET value = 'test'"] error: &error];
	STAssertNil (error, [error localizedDescription]);
	MKCAssertTrue (3 == count);
}

- (void) testNullValidation
{
	NSError* error = nil;
	BXEntityDescription* person = [context entityForTable: @"person" error: &error];
	NSArray* people = [context executeFetchForEntity: person withPredicate: nil error: &error];
	BXDatabaseObject* personObject = [people objectAtIndex: 0];
	
	//soulmate has a non-null constraint.
	id value = nil;
	[personObject validateValue: &value forKey: @"soulmate" error: &error];
	STAssertEqualObjects ([error domain], kBXErrorDomain, [error localizedDescription]);
	STAssertTrue ([error code] == kBXErrorNullConstraintNotSatisfied, [error localizedDescription]);
	
	error = nil;
	value = [NSNull null];
	[personObject validateValue: &value forKey: @"soulmate" error: &error];
	STAssertEqualObjects ([error domain], kBXErrorDomain, [error localizedDescription]);
	STAssertTrue ([error code] == kBXErrorNullConstraintNotSatisfied, [error localizedDescription]);
	
	error = nil;
	value = [NSNumber numberWithInt: 1];
	[personObject validateValue: &value forKey: @"soulmate" error: &error];
	STAssertNil (error, [error localizedDescription]);
}

- (void) testExclusion
{
	NSError* error = nil;
	NSString* fieldname = @"value";
	[context connectIfNeeded: &error];
	STAssertNil (error, [error localizedDescription]);
	BXAttributeDescription* property = [[entity attributesByName] objectForKey: fieldname];
	MKCAssertFalse ([property isExcluded]);

	NSArray* result = [context executeFetchForEntity: entity withPredicate: nil 
									 excludingFields: [NSArray arrayWithObject: fieldname]
											   error: &error];
	STAssertNil (error, [error localizedDescription]);
	MKCAssertTrue ([property isExcluded]);
	
	//Quite the same, which object we get
	BXDatabaseObject* object = [result objectAtIndex: 0]; 
	MKCAssertTrue (1 == [object isFaultKey: fieldname]);
	[context fireFault: object key: fieldname error: &error];
	STAssertNil (error, [error localizedDescription]);
	MKCAssertTrue (0 == [object isFaultKey: fieldname]);
	
	[entity resetAttributeExclusion];
}

- (void) testJoin
{
	NSError* error = nil;
	[context connectIfNeeded: &error];
	STAssertNil (error, [error localizedDescription]);
	
	BXEntityDescription* person = [context entityForTable: @"person" error: &error];
	STAssertNil (error, [error localizedDescription]);
	
	BXPropertyDescription* person_id = [[person attributesByName] objectForKey: @"id"];
	BXPropertyDescription* test_id = [[entity attributesByName] objectForKey: @"id"];
	MKCAssertNotNil (person_id);
	MKCAssertNotNil (test_id);
	
	NSExpression* lhs = [NSExpression expressionForConstantValue: person_id];
	NSExpression* rhs = [NSExpression expressionForConstantValue: test_id];
	NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs
																	   modifier: NSDirectPredicateModifier 
																		   type: NSEqualToPredicateOperatorType
																		options: 0];
	MKCAssertNotNil (predicate);
	
	//Make another predicate just to test compound predicates.
	NSPredicate* truePredicate = [NSPredicate predicateWithFormat: @"TRUEPREDICATE"];
	MKCAssertNotNil (truePredicate);
	NSPredicate* compound = [NSCompoundPredicate andPredicateWithSubpredicates: 
		[NSArray arrayWithObjects: predicate, truePredicate, nil]];
	
	NSArray* res = [context executeFetchForEntity: person withPredicate: compound error: &error];
	STAssertNil (error, [error localizedDescription]);
	
	MKCAssertTrue (1 == [res count]);
	MKCAssertEqualObjects ([[res objectAtIndex: 0] valueForKey: @"name"], @"nzhuk");
}

#if 0
- (void) testJoin2
{
	NSError* error = nil;	
	[context connectIfNeeded: &error];
	STAssertNil (error, [error localizedDescription]);
	
	BXEntityDescription* order = [context entityForTable: @"order" error: &error];
	STAssertNil (error, [error localizedDescription]);
	BXEntityDescription* supplier = [context entityForTable: @"supplier" error: &error];
	STAssertNil (error, [error localizedDescription]);
	
	BXPropertyDescription* supplierName = [[supplier attributesByName] objectForKey: @"supplier_name"];
	BXPropertyDescription* poNumber = [[order attributesByName] objectForKey: @"po_number"];
	BXPropertyDescription* supplierId = [[supplier attributesByName] objectForKey: @"supplier_id"];
	BXPropertyDescription* orderSupplierId = [[order attributesByName] objectForKey: @"supplier_id"];
	MKCAssertNotNil (supplierName);
	MKCAssertNotNil (poNumber);
	MKCAssertNotNil (supplierId);
	MKCAssertNotNil (orderSupplierId);
	
    NSPredicate* predicate = [NSPredicate predicateWithFormat: 
        @"%@ == %@ AND ((NOT %@ MATCHES[c] \"test\") OR %@ MATCHES[c] \"ferg\")", 
		supplierId, orderSupplierId, poNumber, supplierName];
    
	NSArray* res = [context executeFetchForEntity: order withPredicate: predicate error: &error];
	res = nil;
}
#endif

- (void) testFault
{
	NSError* error = nil;
	[entity setDatabaseObjectClass: [FetchTestObject class]];
	NSArray* res = [context executeFetchForEntity: entity withPredicate: [NSPredicate predicateWithFormat: @"id = 1"]
								  returningFaults: NO error: &error];
	STAssertNil (error, [error localizedDescription]);
	
	FetchTestObject* object = [res objectAtIndex: 0];
	MKCAssertFalse ([object isFaultKey: nil]);
	MKCAssertFalse ([object isFaultKey: @"value"]);
	
	object->didTurnIntoFault = NO;
	[object faultKey: @"value"];
	MKCAssertTrue (object->didTurnIntoFault);
	MKCAssertTrue ([object isFaultKey: nil]);
	MKCAssertTrue ([object isFaultKey: @"value"]);
	MKCAssertFalse ([object isFaultKey: @"id"]);
	
	object->didTurnIntoFault = NO;
	[object primitiveValueForKey: @"value"];
	[object faultKey: nil];
	MKCAssertTrue (object->didTurnIntoFault);	
	MKCAssertTrue ([object isFaultKey: nil]);
	MKCAssertTrue ([object isFaultKey: @"value"]);
	
	object->didTurnIntoFault = NO;
	[object valueForKey: @"value"];
	[context refreshObject: object mergeChanges: YES];
	MKCAssertFalse (object->didTurnIntoFault);
	MKCAssertFalse ([object isFaultKey: nil]);
	MKCAssertFalse ([object isFaultKey: @"value"]);
	
	object->didTurnIntoFault = NO;
	[object valueForKey: @"value"];
	[context refreshObject: object mergeChanges: NO];
	MKCAssertTrue (object->didTurnIntoFault);
	MKCAssertTrue ([object isFaultKey: nil]);
	MKCAssertTrue ([object isFaultKey: @"value"]);
		
	[entity setDatabaseObjectClass: nil];
}

@end
