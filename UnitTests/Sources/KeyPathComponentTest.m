//
// KeyPathComponentTest.m
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

#import "KeyPathComponentTest.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BXKeyPathParser.h>


@implementation KeyPathComponentTest
- (void) testKeyPath
{
	NSString* keyPath = @"aa.bb.cc";
	NSArray* components = BXKeyPathComponents (keyPath);
	MKCAssertEqualObjects (components, ([NSArray arrayWithObjects: @"aa", @"bb", @"cc", nil]));
}

- (void) testQuotedKeyPAth
{
	NSString* keyPath = @"\"aa.bb\".cc";
	NSArray* components = BXKeyPathComponents (keyPath);
	MKCAssertEqualObjects (components, ([NSArray arrayWithObjects: @"aa.bb", @"cc", nil]));
}

- (void) testSingleComponent
{
	NSString* keyPath = @"aa";
	NSArray* components = BXKeyPathComponents (keyPath);
	MKCAssertEqualObjects (components, ([NSArray arrayWithObjects: @"aa", nil]));
}

- (void) testRecurringFullStops
{
	NSString* keyPath = @"aa..bb";
	MKCAssertThrowsSpecificNamed (BXKeyPathComponents (keyPath), NSException, NSInvalidArgumentException);
}

- (void) testEndingFullStop
{
	NSString* keyPath = @"aa.";
	MKCAssertThrowsSpecificNamed (BXKeyPathComponents (keyPath), NSException, NSInvalidArgumentException);
}

- (void) testBeginningFullStop
{
	NSString* keyPath = @".aa";
	MKCAssertThrowsSpecificNamed (BXKeyPathComponents (keyPath), NSException, NSInvalidArgumentException);
}
@end
