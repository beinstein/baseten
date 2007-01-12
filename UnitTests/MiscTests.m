//
// MiscTests.m
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
// $Id: CreateTests.m 85 2007-01-12 13:08:00Z tuukka.norri@karppinen.fi $
//

#import <BaseTen/BaseTen.h>
#import "MiscTests.h"
#import "MKCSenTestCaseAdditions.h"


@implementation MiscTests

- (void) setUp
{
    ctx = [[BXDatabaseContext alloc] initWithDatabaseURI: [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"]];
	[ctx setAutocommits: NO];
}

- (void) tearDown
{
    [ctx release];
}

- (void) testDate
{
	NSError* error = nil;
	BXEntityDescription* entity = [ctx entityForTable: @"datetest" error: &error];
	MKCAssertNil (error);
	
	NSArray* res = [ctx executeFetchForEntity: entity withPredicate: nil error: &error];
	MKCAssertNil (error);
	
	NSCalendarDate* date = [[res objectAtIndex: 0] date];
	NSCalendarDate* refDate = [NSCalendarDate dateWithString: @"2007-01-12 16:18:56"
											  calendarFormat: @"%2Y-%2m-%2d %2H:%2M:%2S"];
	refDate = [refDate addTimeInterval: 0.682369];
	[refDate setTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"EET"]];
	MKCAssertEqualObjects (date, refDate);
}

@end
