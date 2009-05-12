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
	
	NSUInteger units = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	NSDateComponents* components = [calendar components: units fromDate: date];
	
	MKCAssertTrue (2009 == [components year]);
	MKCAssertTrue (5 == [components month]);
	MKCAssertTrue (2 == [components day]);
}

- (void) testTime
{
	const char* dateString = "10:02:05";
	NSDate* date = [PGTSTime newForPGTSResultSet: nil withCharacters: dateString type: nil];
	
	NSUInteger units = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar] autorelease];
	NSDateComponents* components = [calendar components: units fromDate: date];
	
	MKCAssertTrue (10 == [components hour]);
	MKCAssertTrue (2 == [components minute]);
	MKCAssertTrue (5 == [components second]);
}

@end
