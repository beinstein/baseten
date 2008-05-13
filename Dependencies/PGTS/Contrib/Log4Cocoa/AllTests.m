//
//  AllTests.m
//  Log4Cocoa
//
//  Created by bob frank on Sun May 04 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "AllTests.h"
#import "L4LevelTest.h"
#import "L4PatternLayoutTest.h"
#import "L4FileAppenderTest.h"
#import "L4RollingFileAppenderTest.h"
#import "L4DailyRollingFileAppenderTest.h"

@implementation AllTests

+ (TestSuite *) suite
{
    TestSuite *suite = [TestSuite suiteWithName: @"My Tests"];

    // Add your tests here ...
    //
    [suite addTest: [TestSuite suiteWithClass: [L4LevelTest class]]];
	[suite addTest: [TestSuite suiteWithClass: [L4PatternLayoutTest class]]];
	[suite addTest: [TestSuite suiteWithClass: [L4FileAppenderTest class]]];
	[suite addTest: [TestSuite suiteWithClass: [L4RollingFileAppenderTest class]]];
	[suite addTest: [TestSuite suiteWithClass: [L4DailyRollingFileAppenderTest class]]];

    return suite;
}


@end
