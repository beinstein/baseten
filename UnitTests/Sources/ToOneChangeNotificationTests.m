//
// ToOneChangeNotificationTests.h
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

#import <SenTestingKit/SenTestingKit.h>
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXAttributeDescriptionPrivate.h>
#import "ToOneChangeNotificationTests.h"
#import "TestLoader.h"
#import "MKCSenTestCaseAdditions.h"


static NSString* kObservingContext = @"ToOneChangeNotificationTestsObservingContext";


//In situations like A <-->> B and A <--> B database objects on 
//both (to-one) sides should post KVO change notifications.
@implementation ToOneChangeNotificationTests
- (void) setUp
{
	[super setUp];
	
	mA = nil;
	mB1 = nil;
	mB2 = nil;
	
	mReceivedForA = 0;
	mReceivedForB1 = 0;
	mReceivedForB2 = 0;
	
	[mContext connectSync: NULL];
	mTest1 = [[mContext entityForTable: @"test1" inSchema: @"Fkeytest" error: NULL] retain];
	mTest2 = [[mContext entityForTable: @"test2" inSchema: @"Fkeytest" error: NULL] retain];
}


- (void) tearDown
{
	[mTest1 release];
	[mTest2 release];
	[super tearDown];
}


- (void) testAttributeDependency
{
	NSDictionary* attributes = [mTest2 attributesByName];
	MKCAssertNotNil (attributes);
	BXAttributeDescription* attr = [attributes objectForKey: @"fkt1id"];
	MKCAssertNotNil (attr);
	NSSet* deps = [attr dependentRelationships];
	MKCAssertTrue (0 < [deps count]);
}


- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary *) change context: (void *) context
{
    if (kObservingContext == context) 
	{
		if (mA == object)
			mReceivedForA++;
		else if (mB1 == object)
			mReceivedForB1++;
		else if (mB2 == object)
			mReceivedForB2++;
		else
			NSLog (@"Got a strange KVO notification.");
	}
	else 
	{
		[super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
	}
}


//Get one object from test2 (a) and two from test1 (b1, b2). Replace a's reference to b1 with b2.
- (void) testOneToMany
{
	NSPredicate* p = [NSPredicate predicateWithFormat: @"id == 2"];
	NSArray* r1 = [mContext executeFetchForEntity: mTest1 withPredicate: p error: NULL];
	NSArray* r2 = [mContext executeFetchForEntity: mTest2 withPredicate: p error: NULL];
	
	mA = [r2 objectAtIndex: 0];
	mB1 = [mA primitiveValueForKey: @"test1"];
	mB2 = [r1 objectAtIndex: 0];

	MKCAssertNotNil (mA);
	MKCAssertNotNil (mB1);
	MKCAssertNotNil (mB2);
	MKCAssertFalse (mB1 == mB2);
	
	[mA addObserver: self forKeyPath: @"test1" options: 0 context: kObservingContext];
	[mB1 addObserver: self forKeyPath: @"test2" options: 0 context: kObservingContext];
	[mB2 addObserver: self forKeyPath: @"test2" options: 0 context: kObservingContext];
	
	MKCAssertEquals (0, mReceivedForA);
	MKCAssertEquals (0, mReceivedForB1);
	MKCAssertEquals (0, mReceivedForB2);
	
	[mA setPrimitiveValue: [NSNull null] forKey: @"fkt1id"];
	MKCAssertTrue (0 < mReceivedForA);
	MKCAssertTrue (0 < mReceivedForB1);
	MKCAssertEquals (0, mReceivedForB2);
	
	mReceivedForA = 0;
	mReceivedForB1 = 0;
	mReceivedForB2 = 0;
	
	[mA setPrimitiveValue: [NSNumber numberWithInteger: 2] forKey: @"fkt1id"];
	MKCAssertTrue (0 < mReceivedForA);
	MKCAssertEquals (0, mReceivedForB1);
	MKCAssertTrue (0 < mReceivedForB2);
	
	[mA removeObserver: self forKeyPath: @"test1"];
	[mB1 removeObserver: self forKeyPath: @"test2"];
	[mB2 removeObserver: self forKeyPath: @"test2"];
}


//Get one object from ototest1 (a) and two from ototest2 (b1, b2). Replace a's reference to b1 with b2.
- (void) testOneToOne
{
	NSPredicate* p1 = [NSPredicate predicateWithFormat: @"id == 1"];
	NSPredicate* p2 = [NSPredicate predicateWithFormat: @"id == 3"];
	BXEntityDescription* ototest1 = [mContext entityForTable: @"ototest1" inSchema: @"Fkeytest" error: NULL];
	BXEntityDescription* ototest2 = [mContext entityForTable: @"ototest2" inSchema: @"Fkeytest" error: NULL];
	NSArray* r1 = [mContext executeFetchForEntity: ototest1 withPredicate: p1 error: NULL];
	NSArray* r2 = [mContext executeFetchForEntity: ototest2 withPredicate: p2 error: NULL];
	
	mA = [r1 objectAtIndex: 0];
	mB1 = [mA primitiveValueForKey: @"ototest2"];
	mB2 = [r2 objectAtIndex: 0];
	
	MKCAssertNotNil (mA);
	MKCAssertNotNil (mB1);
	MKCAssertNotNil (mB2);
	MKCAssertFalse (mB1 == mB2);
	
	[mA addObserver: self forKeyPath: @"ototest2" options: 0 context: kObservingContext];
	[mB1 addObserver: self forKeyPath: @"ototest1" options: 0 context: kObservingContext];
	[mB2 addObserver: self forKeyPath: @"ototest1" options: 0 context: kObservingContext];
	
	MKCAssertEquals (0, mReceivedForA);
	MKCAssertEquals (0, mReceivedForB1);
	MKCAssertEquals (0, mReceivedForB2);

	[mB1 setPrimitiveValue: [NSNull null] forKey: @"r1"];
	MKCAssertTrue (0 < mReceivedForA);
	MKCAssertTrue (0 < mReceivedForB1);
	MKCAssertEquals (0, mReceivedForB2);	
	
	mReceivedForA = 0;
	mReceivedForB1 = 0;
	mReceivedForB2 = 0;
	
	[mB2 setPrimitiveValue: [NSNumber numberWithInteger: 1] forKey: @"r1"];
	MKCAssertTrue (0 < mReceivedForA);
	MKCAssertEquals (0, mReceivedForB1);
	MKCAssertTrue (0 < mReceivedForB2);
	
	[mA removeObserver: self forKeyPath: @"ototest2"];
	[mB1 removeObserver: self forKeyPath: @"ototest1"];
	[mB2 removeObserver: self forKeyPath: @"ototest1"];
}
@end
