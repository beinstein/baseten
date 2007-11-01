//
// TestLoader.m
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

#import "TestLoader.h"
#import <SenTestingKit/SenTestingKit.h>
#import <BaseTen/BXDatabaseAdditions.h>

@class ConnectTest;
@class EntityTests;
@class ObjectIDTests;
@class FetchTests;
@class CreateTests;
@class ModificationTests;
@class ForeignKeyTests;
@class ForeignKeyModificationTests;
@class MTOCollectionTest;
@class MTMCollectionTest;
@class UndoTests;

@interface SenTestSuite (BXAdditions)
- (void) addSuitesForClasses: (NSArray *) anArray;
@end

@implementation SenTestSuite (BXAdditions)
- (void) addSuitesForClasses: (NSArray *) anArray
{
	TSEnumerate (currentClass, e, [anArray objectEnumerator])
	{
		SenTestSuite* suite = [[self class] testSuiteForTestCaseClass: currentClass];
		[self addTest: suite];
	}
}
@end


@implementation TestLoader

- (void) test
{
	NSArray* simpleTestClasses = [NSArray arrayWithObjects:
		[ConnectTest class],
		[EntityTests class],
		[ObjectIDTests class],
		nil];
	NSArray* useCaseTestClasses = [NSArray arrayWithObjects:
		[FetchTests class],
		[CreateTests class],
		[ModificationTests class],
		nil];
	NSArray* relationshipTestClasses = [NSArray arrayWithObjects:
		[ForeignKeyTests class],
		[ForeignKeyModificationTests class],
		[MTOCollectionTest class],
		[MTMCollectionTest class],
		[UndoTests class],
		nil];
	
	SenTestSuite* simpleSuite = [SenTestSuite testSuiteWithName: @"SimpleTests"];
	[simpleSuite addSuitesForClasses: simpleTestClasses];
	
	SenTestSuite* useCaseSuite = [SenTestSuite testSuiteWithName: @"UseCaseTests"];
	[useCaseSuite addSuitesForClasses: useCaseTestClasses];
	
	SenTestSuite* relationshipSuite = [SenTestSuite testSuiteWithName: @"RelationshipTests"];
	[relationshipSuite addSuitesForClasses: relationshipTestClasses];
	
	SenTestSuite* bxSuite = [SenTestSuite testSuiteWithName: @"BaseTenTests"];
	[bxSuite addTestsEnumeratedBy: [[NSArray arrayWithObjects:
		simpleSuite,
		useCaseSuite,
		relationshipSuite,
		nil] objectEnumerator]];
	
	[bxSuite run];
}
	
@end
