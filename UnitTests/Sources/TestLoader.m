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
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXLogger.h>
#import "MKCSenTestCaseAdditions.h"

#import "PGTSInvocationRecorderTests.h"
#import "PGTSHOMTests.h"
#import "BXDelegateProxyTests.h"
#import "NSPredicate+BaseTenAdditionsTests.h"
#import "NSArray+BaseTenAdditionsTests.h"
#import "PGTSValueTests.h"
#import "BXKeyPathComponentTest.h"
#import "BXPredicateTests.h"
#import "BXHostResolverTests.h"
#import "BXDatabaseContextTests.h"

#import "PGTSMetadataTests.h"
#import "PGTSTypeTests.h"
#import "PGTSParameterTests.h"
#import "PGTSNotificationTests.h"
#import "PGTSPgBouncerTests.h"

#import "BXConnectionTests.h"
#import "BXSSLConnectionTests.h"
#import "BXMetadataTests.h"
#import "BXDataModelTests.h"
#import "BXSQLTests.h"
#import "BXDatabaseObjectTests.h"
#import "EntityTests.h"
#import "ObjectIDTests.h"
#import "CreateTests.h"
#import "FetchTests.h"
#import "BXModificationTests.h"
#import "BXArbitrarySQLTests.h"
#import "ForeignKeyTests.h"
#import "ForeignKeyModificationTests.h"
#import "MTOCollectionTest.h"
#import "MTMCollectionTest.h"
#import "UndoTests.h"
#import "ToOneChangeNotificationTests.h"


@implementation BXTestLoader
- (void) test
{
	BXLogSetLevel (kBXLogLevelWarning);
	BXLogSetAbortsOnAssertionFailure (YES);
	
	NSArray* testClasses = [NSArray arrayWithObjects:
							[PGTSInvocationRecorderTests class],
							[PGTSHOMTests class],
							[BXDelegateProxyTests class],
							[NSPredicate_BaseTenAdditionsTests class],
							[NSArray_BaseTenAdditionsTests class],
							[PGTSValueTests class],
							[BXKeyPathComponentTest class],
							[BXPredicateTests class],
							[BXHostResolverTests class],
							[BXDatabaseContextTests class],
							
							[PGTSMetadataTests class],
							[PGTSTypeTests class],
							[PGTSParameterTests class],
							[PGTSNotificationTests class],
							[PGTSPgBouncerTests class],
							
							[BXConnectionTests class],
							[BXSSLConnectionTests class],
							[BXMetadataTests class],
							[BXDataModelTests class],
							[BXSQLTests class],
							[BXDatabaseObjectTests class],
							[EntityTests class],
							[ObjectIDTests class],
							[CreateTests class],
							[FetchTests class],
							[BXModificationTests class],
							[BXArbitrarySQLTests class],
							[ForeignKeyTests class],
							[ForeignKeyModificationTests class],
							[MTOCollectionTest class],
							[MTMCollectionTest class],
							[UndoTests class],
							[ToOneChangeNotificationTests class],
							nil];
	
	//testClasses = [NSArray arrayWithObject: [BXHostResolverTests class]];
	
	for (Class testCaseClass in testClasses)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		SenTestSuite *suite = [SenTestSuite testSuiteForTestCaseClass: testCaseClass];
		SenTestRun *testRun = [suite run];
		STAssertTrue (0 == [testRun unexpectedExceptionCount], @"Had %u unexpected exceptions.", [testRun unexpectedExceptionCount]);
		[pool drain];
	}
}
@end
