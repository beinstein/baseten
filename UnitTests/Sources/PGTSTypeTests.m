//
// PGTSTypeTests.m
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

#import <BaseTen/PGTSConnection.h>
#import <BaseTen/PGTSResultSet.h>
#import "PGTSTypeTests.h"
#import "MKCSenTestCaseAdditions.h"


@implementation PGTSTypeTests
- (void) setUp
{
	[super setUp];
	NSString* connectionString = @"host = 'localhost' user = 'baseten_test_user' dbname = 'basetentest'";
	mConnection = [[PGTSConnection alloc] init];
	BOOL status = [mConnection connectSync: connectionString];
	STAssertTrue (status, [[[mConnection connectionError] userInfo] description]);	
}

- (void) tearDown
{
	[mConnection disconnect];
	[mConnection release];
}

- (void) testPoint
{
	PGTSResultSet* res = [mConnection executeQuery: @"SELECT * FROM point_test"];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	
	[res advanceRow];
	NSValue* value = [res valueForKey: @"value"];
	MKCAssertNotNil (value);
	
	NSPoint point = [value pointValue];
	MKCAssertTrue (NSEqualPoints (NSMakePoint (2.005, 10.0), point));
}

static inline int
f_eq (float a, float b)
{
	float aa = fabsf (a);
	float bb = fabsf (b);
	return (fabsf (aa - bb) <= (FLT_EPSILON * MAX (aa, bb)));
}

- (void) testFloat4
{
	MKCAssertTrue (4 == sizeof (float));
	
	PGTSResultSet* res = [mConnection executeQuery: @"SELECT * FROM float4_test"];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	
	[res advanceRow];
	NSNumber* value = [res valueForKey: @"value"];
	MKCAssertNotNil (value);	

	float f = 2.71828;
	MKCAssertTrue (f_eq (f, [value floatValue]));
}

static inline int
d_eq (double a, double b)
{
	double aa = fabs (a);
	double bb = fabs (b);
	return (fabs (aa - bb) <= (FLT_EPSILON * MAX (aa, bb)));
}

- (void) testFloat8
{
	MKCAssertTrue (8 == sizeof (double));
	
	PGTSResultSet* res = [mConnection executeQuery: @"SELECT * FROM float8_test"];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	
	[res advanceRow];
	NSNumber* value = [res valueForKey: @"value"];
	MKCAssertNotNil (value);
	
	double d = 2.71828;
	MKCAssertTrue (d_eq (d, [value doubleValue]));
}
@end
