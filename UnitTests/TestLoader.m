//
// TestLoader.m
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

#import "TestLoader.h"
#import <SenTestingKit/SenTestingKit.h>
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseAdditions.h>
#import "MKCSenTestCaseAdditions.h"

#import "ConnectTest.h"
#import "EntityTests.h"
#import "ObjectIDTests.h"
#import "FetchTests.h"
#import "CreateTests.h"
#import "ModificationTests.h"
#import "ForeignKeyTests.h"
#import "ForeignKeyModificationTests.h"
#import "MTOCollectionTest.h"
#import "MTMCollectionTest.h"
#import "UndoTests.h"
#import "ObjectTests.h"
#import "PredicateTests.h"
#import "KeyPathComponentTest.h"
#import "ToOneChangeNotificationTests.h"


@interface SenTestCase (UndocumentedMethods)
- (void) logException:(NSException *) anException;
@end


@implementation BXTestLoader
- (void) test
{
	NSArray* testClasses = [NSArray arrayWithObjects:
							[KeyPathComponentTest class],
							[PredicateTests class],
							[ConnectTest class],
							[EntityTests class],
							//[ObjectTests class], //FIXME: enable this. It still requires a modified OCMock, though.
							[ObjectIDTests class],
							[CreateTests class],
							[FetchTests class],
							[ModificationTests class],
							[ForeignKeyTests class],
							[ForeignKeyModificationTests class],
							[MTOCollectionTest class],
							[MTMCollectionTest class],
							[UndoTests class],
							[ToOneChangeNotificationTests class],
							nil];
	
	//testClasses = [NSArray arrayWithObject: [ToOneChangeNotificationTests class]];
	
	for (Class testCaseClass in testClasses)
	{
		SenTestSuite* suite = [SenTestSuite testSuiteForTestCaseClass: testCaseClass];
		[suite run];
	}
}
@end


@implementation BXTestCase
static void
bx_test_failed (NSException* exception)
{
	abort ();
}

- (void) logAndCallBXTestFailed: (NSException *) exception
{
	[self logException: exception];
	bx_test_failed (exception);
}

- (id) initWithInvocation:(NSInvocation *) anInvocation
{
	if ((self = [super initWithInvocation: anInvocation]))
	{
		[self setFailureAction: @selector (logAndCallBXTestFailed:)];
	}
	return self;
}
@end


@implementation BXDatabaseTestCase
- (void) setUp
{
	NSURL* databaseURI = [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"];
	mContext = [[BXDatabaseContext alloc] initWithDatabaseURI: databaseURI];
	[mContext setAutocommits: NO];
}

- (void) tearDown
{
	[mContext disconnect];
	[mContext release];
}
@end
