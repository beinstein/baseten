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

#import "KeyPathComponentTest.h"
#import "PredicateTests.h"
#import "BXDatabaseContextTests.h"
#import "PGTSValueTests.h"

#import "PGTSMetadataTests.h"
#import "PGTSTypeTests.h"
#import "PGTSParameterTests.h"
#import "PGTSNotificationTests.h"
#import "PGTSPgBouncerTests.h"

#import "ConnectTest.h"
#import "BXSSLConnectionTests.h"
#import "BXDataModelTests.h"
#import "BXSQLTests.h"
#import "BXDatabaseObjectTests.h"
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
#import "BXDatabaseObjectTests.h"
#import "ToOneChangeNotificationTests.h"


@implementation BXTestLoader
- (void) test
{
	BXSetLogLevel (kBXLogLevelWarning);
	
	NSArray* testClasses = [NSArray arrayWithObjects:
							[KeyPathComponentTest class],
							[PredicateTests class],
							[BXDatabaseContextTests class],
							[PGTSValueTests class],
							
							[PGTSMetadataTests class],
							[PGTSTypeTests class],
							[PGTSParameterTests class],
							[PGTSNotificationTests class],
							//[PGTSPgBouncerTests class],
							
							[ConnectTest class],
							[BXSSLConnectionTests class],
							[BXDataModelTests class],
							[BXSQLTests class],
							[BXDatabaseObjectTests class],
							[EntityTests class],
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
	
	//testClasses = [NSArray arrayWithObject: [ConnectTest class]];
	
	for (Class testCaseClass in testClasses)
	{
		SenTestSuite* suite = [SenTestSuite testSuiteForTestCaseClass: testCaseClass];
		[suite run];
	}
}
@end
