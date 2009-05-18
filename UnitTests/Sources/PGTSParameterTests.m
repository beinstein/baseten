//
// PGTSParameterTests.m
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
#import <BaseTen/PGTSConstants.h>
#import <BaseTen/PGTSFoundationObjects.h>
#import "PGTSParameterTests.h"
#import "MKCSenTestCaseAdditions.h"


@implementation PGTSParameterTests
- (void) setUp
{
	[super setUp];
	NSDictionary* connectionDictionary = [self connectionDictionary];
	mConnection = [[PGTSConnection alloc] init];
	BOOL status = [mConnection connectSync: connectionDictionary];
	STAssertTrue (status, [[mConnection connectionError] description]);	
}

- (void) tearDown
{
	[mConnection disconnect];
	[mConnection release];
	[super tearDown];
}

- (void) test0String
{
	//Precomposed and astral characters.
	NSString* value = @"teståäöÅÄÖ𐄤𐄧𐄪𐄷";
	//Decomposed and astral characters.
	const char* expected = "teståäöÅÄÖ𐄤𐄧𐄪𐄷";
	
	int length = 0;
	id objectValue = [value PGTSParameter: mConnection];
	const char* paramValue = [objectValue PGTSParameterLength: &length connection: mConnection];
	
	CFRetain (objectValue);
	MKCAssertFalse ([value PGTSIsBinaryParameter]);
	MKCAssertTrue (value == objectValue);
	MKCAssertTrue (0 == strcmp (expected, paramValue));
	CFRelease (objectValue);
}

- (void) test1Data
{
	const char* value = "\000\001\002\003";
	size_t valueLength = strlen (value);
	
	int length = 0;
	NSData* object = [NSData dataWithBytes: value length: length];
	id objectValue = [object PGTSParameter: mConnection];
	const char* paramValue = [objectValue PGTSParameterLength: &length connection: mConnection];
	
	CFRetain (objectValue);
	MKCAssertTrue ([object PGTSIsBinaryParameter]);
	MKCAssertTrue (object == objectValue);
	MKCAssertTrue (length == valueLength);
	MKCAssertTrue (0 == memcmp (value, paramValue, length));
	CFRelease (objectValue);
}

- (void) test2Integer
{
	NSInteger value = -15;
	
	int length = 0;
	NSNumber* object = [NSNumber numberWithInteger: value];
	id objectValue = [object PGTSParameter: mConnection];
	const char* paramValue = [objectValue PGTSParameterLength: &length connection: mConnection];
	
	CFRetain (objectValue);
	MKCAssertFalse ([object PGTSIsBinaryParameter]);
	MKCAssertFalse (object == objectValue);
	MKCAssertTrue (0 == strcmp ("-15", paramValue));
	CFRelease (objectValue);
}

- (void) test3Double
{
	double value = -15.2;
	
	int length = 0;
	NSNumber* object = [NSNumber numberWithDouble: value];
	id objectValue = [object PGTSParameter: mConnection];
	const char* paramValue = [objectValue PGTSParameterLength: &length connection: mConnection];
	
	CFRetain (objectValue);
	MKCAssertFalse ([object PGTSIsBinaryParameter]);
	MKCAssertFalse (object == objectValue);
	MKCAssertTrue (0 == strcmp ("-15.2", paramValue));
	CFRelease (objectValue);
}

- (void) test4Date
{
	//20010105 8:02 am
	NSDate* object = [NSDate dateWithTimeIntervalSinceReferenceDate: 4 * 86400 + 8 * 3600 + 2 * 60];
	
	int length = 0;
	id objectValue = [object PGTSParameter: mConnection];
	const char* paramValue = [objectValue PGTSParameterLength: &length connection: mConnection];
	
	CFRetain (objectValue);
	MKCAssertFalse ([object PGTSIsBinaryParameter]);
	MKCAssertFalse (object == objectValue);
	MKCAssertTrue (0 == strcmp ("2001-01-05 08:02:00+00", paramValue));
	CFRelease (objectValue);
}

- (void) test5CalendarDate
{
	//20010105 8:02 am UTC-1
	NSTimeZone* tz = [NSTimeZone timeZoneForSecondsFromGMT: -3600];
	NSDate* object = [NSCalendarDate dateWithYear: 2001 month: 1 day: 5 hour: 8 minute: 2 second: 0 timeZone: tz];
	
	int length = 0;
	id objectValue = [object PGTSParameter: mConnection];
	const char* paramValue = [objectValue PGTSParameterLength: &length connection: mConnection];
	
	CFRetain (objectValue);
	MKCAssertFalse ([object PGTSIsBinaryParameter]);
	MKCAssertFalse (object == objectValue);
	MKCAssertTrue (0 == strcmp ("2001-01-05 09:02:00+00", paramValue));
	CFRelease (objectValue);
}

- (void) test6Array
{
	NSArray* value = [NSArray arrayWithObjects: @"test", @"-1", nil];
	
	int length = 0;
	id objectValue = [value PGTSParameter: mConnection];
	const char* paramValue = [objectValue PGTSParameterLength: &length connection: mConnection];
	
	CFRetain (objectValue);
	MKCAssertFalse ([value PGTSIsBinaryParameter]);
	MKCAssertFalse (value == objectValue);
	MKCAssertTrue (0 == strcmp ("{\"test\",\"-1\"}", paramValue));
	CFRelease (objectValue);
}

- (void) test7Set
{
	NSSet* value = [NSSet set];
	int length = 0;
	MKCAssertThrowsSpecificNamed ([value PGTSParameter: mConnection], NSException, NSInvalidArgumentException);
	MKCAssertThrowsSpecificNamed ([value PGTSParameterLength: &length connection: mConnection], NSException, NSInvalidArgumentException);
}

- (void) testTimestamp
{
	NSTimeInterval interval = 263856941.04633799; //This caused problems.
	NSDate* value = [NSDate dateWithTimeIntervalSinceReferenceDate: interval];
	
	int length = 0;
	id objectValue = [value PGTSParameter: mConnection];
	const char* paramValue = [objectValue PGTSParameterLength: &length connection: mConnection];
	
	CFRetain (objectValue);
	MKCAssertFalse ([value PGTSIsBinaryParameter]);
	MKCAssertFalse (value == objectValue);
	MKCAssertTrue (0 == strcmp ("2009-05-12 21:35:41.046338+00", paramValue));
	CFRelease (objectValue);	
}

- (void) testTimestamp2
{
	NSTimeInterval interval = 263856941.0000002; //Fractional part that rounds to six zeros.
	NSDate* value = [NSDate dateWithTimeIntervalSinceReferenceDate: interval];
	
	int length = 0;
	id objectValue = [value PGTSParameter: mConnection];
	const char* paramValue = [objectValue PGTSParameterLength: &length connection: mConnection];
	
	CFRetain (objectValue);
	MKCAssertFalse ([value PGTSIsBinaryParameter]);
	MKCAssertFalse (value == objectValue);
	MKCAssertTrue (0 == strcmp ("2009-05-12 21:35:41.000000+00", paramValue));
	CFRelease (objectValue);	
}					
@end
