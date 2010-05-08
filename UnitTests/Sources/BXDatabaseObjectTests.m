//
// BXDatabaseObjectTests.m
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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

#import "BXDatabaseObjectTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <OCMock/OCMock.h>

#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseObjectPrivate.h>
#import <BaseTen/BXDatabaseContextPrivate.h>


@interface BXAttributeDescriptionPlaceholder : NSObject
{
    @public
    NSString* mName;
    BOOL mIsPkey;
    BOOL mIsOptional;
}
@end

@implementation BXAttributeDescriptionPlaceholder
- (void) dealloc
{
    [mName release];
    [super dealloc];
}
- (NSString *) name
{
    return mName;
}
- (NSComparisonResult) compare: (id) anObject
{
    return [mName compare: anObject];
}
- (BOOL) isPrimaryKey
{
    return mIsPkey;
}
- (BOOL) isOptional
{
    return mIsOptional;
}
@end


@implementation BXDatabaseObjectTests
- (void) setUp
{
	[super setUp];
	
    BXAttributeDescriptionPlaceholder* idDesc = [[[BXAttributeDescriptionPlaceholder alloc] init] autorelease];
    idDesc->mName = @"id";
    idDesc->mIsPkey = YES;
    idDesc->mIsOptional = NO;
    
    BXAttributeDescriptionPlaceholder* keyDesc = [[[BXAttributeDescriptionPlaceholder alloc] init] autorelease];
    keyDesc->mName = @"key";
    keyDesc->mIsPkey = NO;
    keyDesc->mIsOptional = YES;
    
    mContext = [OCMockObject niceMockForClass: [BXDatabaseContext class]];
    [[[mContext stub] andReturnValue: [NSNumber numberWithBool: YES]] registerObject: mObject];

    mEntity = [OCMockObject niceMockForClass: [BXEntityDescription class]];
    [[[mEntity stub] andReturn: [NSArray arrayWithObject: idDesc]] primaryKeyFields];
    [[[mEntity stub] andReturn: [NSDictionary dictionaryWithObjectsAndKeys:
        idDesc, @"id",
        keyDesc, @"key",
        nil]] attributesByName];
    [[[mEntity stub] andReturnValue: [NSNumber numberWithBool: YES]] isValidated];
    
    mObject = [[BXDatabaseObject alloc] init];
    MKCAssertNotNil (mObject);
    [mObject setCachedValue: @"value" forKey: @"key"];
    [mObject setCachedValue: [NSNumber numberWithInt: 1] forKey: @"id"];
}

- (void) tearDown
{
    [mContext verify];
    [mEntity verify];    
    
    [mObject release];
	
	[super tearDown];
}

- (void) testCachedValue
{    
    MKCAssertEqualObjects (@"value", [mObject cachedValueForKey: @"key"]);
}
@end
