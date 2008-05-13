//
// MKCSenTestCaseAdditions.h
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

/*!
    Some macros which extend SenTestCase.h with assertion methods which don't require a description string.
    Adds also a macro to run the current runloop in default mode until some condition becomes FALSE or timeout occurs.
*/

#import <SenTestingKit/SenTestingKit.h>

#define MKC_ASSERT_DESCRIPTION @"Assertion failed"

#define MKCAssertNil(a1) STAssertNil(a1, MKC_ASSERT_DESCRIPTION)
#define MKCAssertNotNil(a1) STAssertNotNil(a1, MKC_ASSERT_DESCRIPTION)
#define MKCAssertTrue(expression) STAssertTrue(expression, MKC_ASSERT_DESCRIPTION)
#define MKCAssertFalse(expression) STAssertFalse(expression, MKC_ASSERT_DESCRIPTION)
#define MKCAssertEqualObjects(a1, a2) STAssertEqualObjects(a1, a2, MKC_ASSERT_DESCRIPTION)
#define MKCAssertEquals(a1, a2) STAssertEquals(a1, a2, MKC_ASSERT_DESCRIPTION)
#define MKCAssertEqualsWithAccuracy(left, right, accuracy) STAssertEqualsWithAccuracy(left, right, accuracy, MKC_ASSERT_DESCRIPTION)
#define MKCAssertThrows(expression) STAssertThrows(expression, MKC_ASSERT_DESCRIPTION)
#define MKCAssertThrowsSpecific(expression, specificException) STAssertThrowsSpecific(expression, specificException, MKC_ASSERT_DESCRIPTION)
#define MKCAssertThrowsSpecificNamed(expr, specificException, aName) STAssertThrowsSpecificNamed(expr, specificException, aName, MKC_ASSERT_DESCRIPTION)
#define MKCAssertNoThrow(expression) STAssertNoThrow(expression, MKC_ASSERT_DESCRIPTION)
#define MKCAssertNoThrowSpecific(expression, specificException) STAssertNoThrowSpecific(expression, specificException, MKC_ASSERT_DESCRIPTION)
#define MKCAssertNoThrowSpecificNamed(expr, specificException, aName) STAssertNoThrowSpecificNamed(expr, specificException, aName, MKC_ASSERT_DESCRIPTION)
#define MKCFail() STFail(MKC_ASSERT_DESCRIPTION)
#define MKCAssertTrueNoThrow(expression) STAssertTrueNoThrow(expression, MKC_ASSERT_DESCRIPTION)
#define MKCAssertFalseNoThrow(expression) STAssertFalseNoThrow(expression, MKC_ASSERT_DESCRIPTION)

#define MKCRunLoopRunWithConditionAndTimeout(loopCondition, timeoutInSeconds) \
{ \
    NSDate *runLoopTimeout = [NSDate dateWithTimeIntervalSinceNow: timeoutInSeconds]; \
    while ((loopCondition) && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:runLoopTimeout]) \
    { \
        NSDate *currentDate = [NSDate date]; \
        if([currentDate compare:runLoopTimeout] != NSOrderedAscending) \
            break; \
    } \
}
