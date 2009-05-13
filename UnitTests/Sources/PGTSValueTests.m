//
// PGTSValueTests.m
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

#import "PGTSValueTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/PGTSFoundationObjects.h>
#import <BaseTen/PGTSDates.h>

@implementation PGTSValueTests
- (void) testDate
{
	const char* dateString = "2009-05-02";
	NSDate* date = [PGTSDate newForPGTSResultSet: nil withCharacters: dateString type: nil];
	MKCAssertNotNil (date);
	
	NSUInteger units = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	[calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
	NSDateComponents* components = [calendar components: units fromDate: date];
	
	MKCAssertTrue (2009 == [components year]);
	MKCAssertTrue (5 == [components month]);
	MKCAssertTrue (2 == [components day]);
}

- (void) testDateBeforeJulian
{
	const char* dateString = "0100-05-02";
	NSDate* date = [PGTSDate newForPGTSResultSet: nil withCharacters: dateString type: nil];
	MKCAssertNotNil (date);
	
	NSUInteger units = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	[calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
	NSDateComponents* components = [calendar components: units fromDate: date];
	
	MKCAssertTrue (100 == [components year]);
	MKCAssertTrue (5 == [components month]);
	MKCAssertTrue (2 == [components day]);
}

- (void) testDateBeforeCE
{
	const char* dateString = "2009-05-02 BC";
	NSDate* date = [PGTSDate newForPGTSResultSet: nil withCharacters: dateString type: nil];
	MKCAssertNotNil (date);
	
	NSUInteger units = NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	[calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
	NSDateComponents* components = [calendar components: units fromDate: date];
	
	MKCAssertTrue (2009 == [components year]);
	MKCAssertTrue (5 == [components month]);
	MKCAssertTrue (2 == [components day]);
}

- (void) testTime
{
	const char* dateString = "10:02:05";
	NSDate* date = [PGTSTime newForPGTSResultSet: nil withCharacters: dateString type: nil];
	MKCAssertNotNil (date);
	
	NSUInteger units = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	[calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
	NSDateComponents* components = [calendar components: units fromDate: date];
	
	MKCAssertTrue (10 == [components hour]);
	MKCAssertTrue (2 == [components minute]);
	MKCAssertTrue (5 == [components second]);
}

- (void) testTimeWithFraction
{
	const char* dateString = "10:02:05.00067";
	NSDate* date = [PGTSTime newForPGTSResultSet: nil withCharacters: dateString type: nil];
	MKCAssertNotNil (date);
	NSLog (@"date: %@ %f", date, [date timeIntervalSinceReferenceDate]);
	
	NSUInteger units = NSEraCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	[calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
	NSDateComponents* components = [calendar components: units fromDate: date];
	NSLog (@"date: %@ %f", date, [date timeIntervalSinceReferenceDate]);
	
	MKCAssertTrue (10 == [components hour]);
	MKCAssertTrue (2 == [components minute]);
	MKCAssertTrue (5 == [components second]);
	MKCAssertTrue (1 == [components era]);
	NSLog (@"date: %@ %f", date, [date timeIntervalSinceReferenceDate]);
	
	NSTimeInterval interval = [date timeIntervalSinceReferenceDate];
	NSTimeInterval expected = 36125.00067;
	NSLog (@"date: %@ %f", date, [date timeIntervalSinceReferenceDate]);
	STAssertTrue (d_eq (expected, interval), @"Expected %f to equal %f.", expected, interval);
}

- (void) testTimeWithTimeZone
{
	const char* dateString = "10:02:05-02";
	NSDate* date = [PGTSTime newForPGTSResultSet: nil withCharacters: dateString type: nil];
	MKCAssertNotNil (date);
	
	NSUInteger units = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	[calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
	NSDateComponents* components = [calendar components: units fromDate: date];
	
	MKCAssertTrue (12 == [components hour]);
	MKCAssertTrue (2 == [components minute]);
	MKCAssertTrue (5 == [components second]);
}

- (void) testTimeWithTimeZone2 //With minutes in time zone
{
	const char* dateString = "10:02:05+02:03";
	NSDate* date = [PGTSTime newForPGTSResultSet: nil withCharacters: dateString type: nil];
	MKCAssertNotNil (date);
	
	NSUInteger units = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	[calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 3600 * 2 + 60 * 3]];
	NSDateComponents* components = [calendar components: units fromDate: date];
	
	MKCAssertTrue (10 == [components hour]);
	MKCAssertTrue (2 == [components minute]);
	MKCAssertTrue (5 == [components second]);
}

- (void) testTimeWithTimeZone3 //With seconds in time zone
{
	const char* dateString = "10:02:05+02:03:05";
	NSDate* date = [PGTSTime newForPGTSResultSet: nil withCharacters: dateString type: nil];
	MKCAssertNotNil (date);
	
	NSUInteger units = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	[calendar setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 3600 * 2 + 60 * 3 + 5]];
	NSDateComponents* components = [calendar components: units fromDate: date];
	
	MKCAssertTrue (10 == [components hour]);
	MKCAssertTrue (2 == [components minute]);
	MKCAssertTrue (5 == [components second]);
}
@end
