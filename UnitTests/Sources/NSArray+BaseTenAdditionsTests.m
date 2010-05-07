//
// NSArray+BaseTenAdditionsTests.m
// BaseTen
//
// Copyright (C) 2010 Marko Karppinen & Co. LLC.
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

#import "NSArray+BaseTenAdditionsTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/NSArray+BaseTenAdditions.h>


@implementation NSArray_BaseTenAdditionsTests
- (void) test1
{
	NSArray *a = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	NSPredicate *predicate = [NSPredicate predicateWithFormat: @"SELF = %@", @"b"];
	
	NSMutableArray *others = [NSMutableArray array];
	NSArray *filtered = [a BXFilteredArrayUsingPredicate: predicate others: others substitutionVariables: nil];
	
	MKCAssertEqualObjects (filtered, [NSArray arrayWithObject: @"b"]);
	MKCAssertEqualObjects (others, ([NSArray arrayWithObjects: @"a", @"c", nil]));
}


- (void) test2
{
	NSArray *a = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	NSPredicate *predicate = [NSPredicate predicateWithFormat: @"SELF = $MY_VAR"];
	
	NSMutableArray *others = [NSMutableArray array];
	NSDictionary *vars = [NSDictionary dictionaryWithObject: @"b" forKey: @"MY_VAR"];
	NSArray *filtered = [a BXFilteredArrayUsingPredicate: predicate others: others substitutionVariables: vars];
	
	MKCAssertEqualObjects (filtered, [NSArray arrayWithObject: @"b"]);
	MKCAssertEqualObjects (others, ([NSArray arrayWithObjects: @"a", @"c", nil]));
}
@end
