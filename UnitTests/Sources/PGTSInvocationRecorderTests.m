//
// PGTSInvocationRecorderTests.m
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

#import "PGTSInvocationRecorderTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <OCMock/OCMock.h>
#import <BaseTen/PGTSInvocationRecorder.h>


@protocol PGTSInvocationRecorderTestCallback
- (void) myCallback: (NSInvocation *) invocation userInfo: (id) userInfo;
@end



@implementation PGTSInvocationRecorderTests
- (void) test1
{
	NSString *s = @"a";
	PGTSInvocationRecorder *recorder = [[PGTSInvocationRecorder alloc] init];
	[recorder setTarget: s];
	[[recorder record] uppercaseString];
	
	NSInvocation *invocation = [recorder invocation];
	SEL selector = @selector (uppercaseString);
	MKCAssertEquals (s, [invocation target]);
	MKCAssertTrue (0 == strcmp ((const char *) selector, (const char *) [invocation selector]));
	MKCAssertEqualObjects ([s methodSignatureForSelector: selector], [invocation methodSignature]);
}


- (void) test2
{
	NSString *s = @"a";
	NSInvocation *invocation = nil;
	[[PGTSInvocationRecorder recordWithTarget: s outInvocation: &invocation] uppercaseString];
	
	SEL selector = @selector (uppercaseString);
	MKCAssertEquals (s, [invocation target]);
	MKCAssertTrue (0 == strcmp ((const char *) selector, (const char *) [invocation selector]));
	MKCAssertEqualObjects ([s methodSignatureForSelector: selector], [invocation methodSignature]);
}


- (void) test3
{
	NSString *s = @"a";
	NSCharacterSet *set = [NSCharacterSet alphanumericCharacterSet];
	NSStringCompareOptions opts = NSCaseInsensitiveSearch;
	NSInvocation *invocation = nil;
	[[PGTSInvocationRecorder recordWithTarget: s outInvocation: &invocation] rangeOfCharacterFromSet: set options: opts];
	
	SEL selector = @selector (rangeOfCharacterFromSet:options:);
	MKCAssertEquals (s, [invocation target]);
	MKCAssertTrue (0 == strcmp ((const char *) selector, (const char *) [invocation selector]));
	MKCAssertEqualObjects ([s methodSignatureForSelector: selector], [invocation methodSignature]);
	
	NSCharacterSet *invocationSet = nil;
	NSStringCompareOptions invocationOpts = 0;
	[invocation getArgument: &invocationSet atIndex: 2];
	[invocation getArgument: &invocationOpts atIndex: 3];
	MKCAssertEquals (set, invocationSet);
	MKCAssertEquals (opts, invocationOpts);
}


- (void) test4
{
	NSString *a = @"a";
	NSString *b = @"b";
	OCMockObject *callbackTarget = [OCMockObject mockForProtocol: @protocol (PGTSInvocationRecorderTestCallback)];
	
	PGTSCallbackInvocationRecorder *recorder = [[[PGTSCallbackInvocationRecorder alloc] init] autorelease];
	[recorder setCallback: @selector (myCallback:userInfo:)];
	[recorder setCallbackTarget: callbackTarget];
	[recorder setUserInfo: b];
	
	[[callbackTarget expect] myCallback: OCMOCK_ANY userInfo: b];
	[[recorder recordWithTarget: a] uppercaseString];
}
@end
