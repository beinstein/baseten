//
// PGTSHOMTests.m
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

#import "PGTSHOMTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/PGTSHOM.h>
#import <OCMock/OCMock.h>


@implementation PGTSHOMTests
- (void) test01ArrayAny
{
	NSArray *array = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	id object = [array PGTSAny];
	MKCAssertTrue ([array containsObject: object]);
}


- (void) test02SetAny
{
	NSSet *set = [NSSet setWithObjects: @"a", @"b", @"c", nil];
	id object = [set PGTSAny];
	MKCAssertTrue ([set containsObject: object]);
}


- (void) test03DictAny
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  @"a", @"1",
						  @"b", @"2",
						  @"c", @"3",
						  nil];
	id object = [dict PGTSAny];
	MKCAssertTrue ([[dict allValues] containsObject: object]);
}


- (void) test04SetDo
{
	OCMockObject *m1 = [OCMockObject mockForClass: [NSNumber class]];
	OCMockObject *m2 = [OCMockObject mockForClass: [NSNumber class]];
	[[m1 expect] stringValue];
	[[m2 expect] stringValue];
	
	NSSet *set = [NSSet setWithObjects: m1, m2, nil];
	[[set PGTSDo] stringValue];
	
	[m1 verify];
	[m2 verify];
}


- (void) test05ArrayDo
{
	OCMockObject *m1 = [OCMockObject mockForClass: [NSNumber class]];
	OCMockObject *m2 = [OCMockObject mockForClass: [NSNumber class]];
	[[m1 expect] stringValue];
	[[m2 expect] stringValue];
	
	NSArray *array = [NSArray arrayWithObjects: m1, m2, nil];
	[[array PGTSDo] stringValue];
	
	[m1 verify];
	[m2 verify];
}


- (void) test06DictDo
{
	OCMockObject *m1 = [OCMockObject mockForClass: [NSNumber class]];
	OCMockObject *m2 = [OCMockObject mockForClass: [NSNumber class]];
	[[m1 expect] stringValue];
	[[m2 expect] stringValue];

	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  m1, @"a",
						  m2, @"b",
						  nil];
	[[dict PGTSDo] stringValue];
	
	[m1 verify];
	[m2 verify];
}


- (void) test07ArrayCollect
{
	NSArray *array1 = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	NSArray *array2 = (id) [[array1 PGTSCollect] uppercaseString];
	MKCAssertEqualObjects (array2, ([NSArray arrayWithObjects: @"A", @"B", @"C", nil]));
}


- (void) test08SetCollect
{
	NSSet *set1 = [NSSet setWithObjects: @"a", @"b", @"c", nil];
	NSSet *set2 = (id) [[set1 PGTSCollect] uppercaseString];
	MKCAssertEqualObjects (set2, ([NSSet setWithObjects: @"A", @"B", @"C", nil]));
}


- (void) test09DictCollect
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  @"a", @"1",
						  @"b", @"2",
						  @"c", @"3",
						  nil];
	NSArray *array = (id) [[dict PGTSCollect] uppercaseString];
	MKCAssertEqualObjects (array, ([NSArray arrayWithObjects: @"A", @"B", @"C", nil]));
}


- (void) test10ArrayCollectRet
{
	NSArray *array = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	NSSet *set = (id) [[array PGTSCollectReturning: [NSMutableSet class]] uppercaseString];
	MKCAssertEqualObjects (set, ([NSSet setWithObjects: @"A", @"B", @"C", nil]));
}


- (void) test11SetCollectRet
{
	NSSet *set = [NSSet setWithObjects: @"a", @"b", @"c", nil];
	NSArray *array = (id) [[set PGTSCollectReturning: [NSMutableArray class]] uppercaseString];
	MKCAssertEqualObjects ([array sortedArrayUsingSelector: @selector (compare:)],
						   ([NSArray arrayWithObjects: @"A", @"B", @"C", nil]));
}


- (void) test12DictCollectRet
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  @"a", @"1",
						  @"b", @"2",
						  @"c", @"3",
						  nil];
	NSSet *set = (id) [[dict PGTSCollectReturning: [NSMutableSet class]] uppercaseString];
	MKCAssertEqualObjects (set, ([NSSet setWithObjects: @"A", @"B", @"C", nil]));
}


- (void) test13ArrayCollectD
{
	NSArray *array = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	NSDictionary *dict = (id) [[array PGTSCollectD] uppercaseString];
	MKCAssertEqualObjects (dict, ([NSDictionary dictionaryWithObjectsAndKeys:
								   @"a", @"A",
								   @"b", @"B",
								   @"c", @"C",
								   nil]));
}


- (void) test14SetCollectD
{
	NSSet *set = [NSSet setWithObjects: @"a", @"b", @"c", nil];
	NSDictionary *dict = (id) [[set PGTSCollectD] uppercaseString];
	MKCAssertEqualObjects (dict, ([NSDictionary dictionaryWithObjectsAndKeys:
								   @"a", @"A",
								   @"b", @"B",
								   @"c", @"C",
								   nil]));
}


- (void) test15DictCollectD
{
	NSSet *dict1 = [NSDictionary dictionaryWithObjectsAndKeys:
					@"a", @"1",
					@"b", @"2",
					@"c", @"3",
					nil];
	NSDictionary *dict2 = (id) [[dict1 PGTSCollectD] uppercaseString];
	MKCAssertEqualObjects (dict2, ([NSDictionary dictionaryWithObjectsAndKeys:
									@"a", @"A",
									@"b", @"B",
									@"c", @"C",
									nil]));
}


- (void) test16ArrayCollectDK
{
	NSArray *array = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	NSDictionary *dict = (id) [[array PGTSCollectDK] uppercaseString];
	MKCAssertEqualObjects (dict, ([NSDictionary dictionaryWithObjectsAndKeys:
								   @"A", @"a",
								   @"B", @"b",
								   @"C", @"c",
								   nil]));
}


- (void) test17SetCollectDK
{
	NSSet *set = [NSSet setWithObjects: @"a", @"b", @"c", nil];
	NSDictionary *dict = (id) [[set PGTSCollectDK] uppercaseString];
	MKCAssertEqualObjects (dict, ([NSDictionary dictionaryWithObjectsAndKeys:
								   @"A", @"a",
								   @"B", @"b",
								   @"C", @"c",
								   nil]));
}


- (void) test18DictCollectDK
{
	NSSet *dict1 = [NSDictionary dictionaryWithObjectsAndKeys:
					@"a", @"1",
					@"b", @"2",
					@"c", @"3",
					nil];
	NSDictionary *dict2 = (id) [[dict1 PGTSCollectDK] uppercaseString];
	MKCAssertEqualObjects (dict2, ([NSDictionary dictionaryWithObjectsAndKeys:
									@"A", @"a",
									@"B", @"b",
									@"C", @"c",
									nil]));
}


- (void) test19ArrayVisit
{	
	OCMockObject *mock = [OCMockObject mockForClass: [NSUserDefaults class]];
	[[mock expect] objectIsForcedForKey: @"a" inDomain: @"b"];
	
	NSArray *array = [NSArray arrayWithObject: @"a"];
	[[array PGTSVisit: mock] objectIsForcedForKey: nil inDomain: @"b"];
	
	[mock verify];
}


- (void) test20ArrayVisit
{	
	OCMockObject *mock = [OCMockObject mockForClass: [NSUserDefaults class]];
	[[mock expect] objectIsForcedForKey: @"a" inDomain: @"b"];
	
	NSSet *set = [NSSet setWithObject: @"a"];
	[[set PGTSVisit: mock] objectIsForcedForKey: nil inDomain: @"b"];
	
	[mock verify];
}


- (void) test21DictVisit
{	
	OCMockObject *mock = [OCMockObject mockForClass: [NSUserDefaults class]];
	[[mock expect] objectIsForcedForKey: @"a" inDomain: @"b"];
	
	NSDictionary *dict = [NSDictionary dictionaryWithObject: @"a" forKey: @"1"];
	[[dict PGTSVisit: mock] objectIsForcedForKey: nil inDomain: @"b"];
	
	[mock verify];
}


- (void) test22ArrayReverse
{
	NSArray *array = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	MKCAssertEqualObjects ([array PGTSReverse], ([NSArray arrayWithObjects: @"c", @"b", @"a", nil]));
}


- (void) test23DictKeyCollectD
{
	NSDictionary *dict1 = [NSDictionary dictionaryWithObjectsAndKeys:
						   @"1", @"a",
						   @"2", @"b",
						   @"3", @"c",
						   nil];
	NSDictionary *dict2 = (id) [[dict1 PGTSKeyCollectD] uppercaseString];
	MKCAssertEqualObjects (dict2, ([NSDictionary dictionaryWithObjectsAndKeys:
									@"a", @"A",
									@"b", @"B",
									@"c", @"C",
									nil]));	
}


static int
SelectFunction (id object)
{
	int retval = 1;
	if ([object isEqual: @"b"])
		retval = 0;
	return retval;
}


- (void) test24ArraySelectFunction
{
	NSArray *array = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	MKCAssertEqualObjects ([array PGTSSelectFunction: &SelectFunction], ([NSArray arrayWithObjects: @"a", @"c", nil]));
}


- (void) test25SetSelectFunction
{
	NSSet *set = [NSSet setWithObjects: @"a", @"b", @"c", nil];
	MKCAssertEqualObjects ([set PGTSSelectFunction: &SelectFunction], ([NSSet setWithObjects: @"a", @"c", nil]));
}


- (void) test26ValueSelectFunction
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  @"a", @"1",
						  @"b", @"2",
						  @"c", @"3",
						  nil];
	MKCAssertEqualObjects ([dict PGTSValueSelectFunction: &SelectFunction], ([NSArray arrayWithObjects: @"a", @"c", nil]));
}


static int
SelectFunction2 (id object, void *arg)
{
	assert ([(id) arg isEqual: @"k"]);
	
	int retval = 1;
	if ([object isEqual: @"b"])
		retval = 0;
	return retval;
}


- (void) test27ArraySelectFunction
{
	NSArray *array = [NSArray arrayWithObjects: @"a", @"b", @"c", nil];
	MKCAssertEqualObjects ([array PGTSSelectFunction: &SelectFunction2 argument: @"k"], ([NSArray arrayWithObjects: @"a", @"c", nil]));
}


- (void) test28SetSelectFunction
{
	NSSet *set = [NSSet setWithObjects: @"a", @"b", @"c", nil];
	MKCAssertEqualObjects ([set PGTSSelectFunction: &SelectFunction2 argument: @"k"], ([NSSet setWithObjects: @"a", @"c", nil]));
}


- (void) test29ValueSelectFunction
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  @"a", @"1",
						  @"b", @"2",
						  @"c", @"3",
						  nil];
	MKCAssertEqualObjects ([dict PGTSValueSelectFunction: &SelectFunction2 argument: @"k"], ([NSArray arrayWithObjects: @"a", @"c", nil]));
}
@end
