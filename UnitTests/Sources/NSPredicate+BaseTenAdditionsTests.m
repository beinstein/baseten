//
// NSPredicate+BaseTenAdditionsTests.m
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

#import "NSPredicate+BaseTenAdditionsTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/NSPredicate+BaseTenAdditions.h>


@implementation NSPredicate_BaseTenAdditionsTests
- (void) test1
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat: @"SELF = $MY_VAR"];
	NSDictionary *vars = [NSDictionary dictionaryWithObject: @"a" forKey: @"MY_VAR"];
	MKCAssertTrue ([predicate BXEvaluateWithObject: @"a" substitutionVariables: vars]);
	MKCAssertFalse ([predicate BXEvaluateWithObject: @"b" substitutionVariables: vars]);
}
@end
