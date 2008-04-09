//
//  L4DailyRollingFileAppenderTest.m
//  Log4Cocoa
//
//  Created by Michael James on Thu Apr 29 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "L4DailyRollingFileAppenderTest.h"
#import "L4DailyRollingFileAppender.h"
#import "L4Layout.h"

#define TEST_DRFA_OUTPUTDIR [@"~/Desktop/DRFATest" stringByExpandingTildeInPath]
#define TEST_DRFA_LOG_OUTPUTFILE [@"~/Desktop/DRFATest/testDailyRollingFileAppender" stringByExpandingTildeInPath]

@implementation L4DailyRollingFileAppenderTest

- (void)setUp
{
	_drfa = [[L4DailyRollingFileAppender alloc] init];
}

- (void)tearDown
{
	[[self l4Logger] removeAppender: _drfa];
	
	[_drfa release];
	_drfa = nil;
}

- (void)testCreation
{
	[self assertNotNil: _drfa message: @"_drfa is nil!"];
	[self assertTrue: ([_drfa rollingFrequency] == never) message: @"_drfa's rolling frequency is not never!"];
}

- (void)testSetRollingFrequency
{
	[_drfa setRollingFrequency: minutely];
	[self assertTrue: ([_drfa rollingFrequency] == minutely) message: @"_drfa's rolling frequency is not minuntely!"];
}

- (void)testLogging
{
	NSDate*				now = nil;
	NSDate*				aMinuteFromNow = nil;
	L4PatternLayout*	pl = nil;
	NSFileManager*		fm = [NSFileManager defaultManager];
	
	pl = [[[L4PatternLayout alloc] initWithConversionPattern: @"%m"] autorelease];
	[_drfa setLayout: pl];
	
	[fm createDirectoryAtPath: TEST_DRFA_OUTPUTDIR attributes: nil];
		
	now = [NSDate date];
	aMinuteFromNow = [NSDate dateWithTimeIntervalSinceNow: 61];

	[_drfa setFileName: TEST_DRFA_LOG_OUTPUTFILE];
	[_drfa setRollingFrequency: minutely];
	[_drfa activateOptions];	
	
	[[self l4Logger] addAppender: _drfa];
	log4Debug(@"This is the first test logging statement!", nil);
	
	[NSThread sleepUntilDate: aMinuteFromNow];
	log4Debug(@"This is the second test logging statement!", nil);
	
	[self assertTrue: ([[fm directoryContentsAtPath: TEST_DRFA_OUTPUTDIR] count] >= 2) message: @"There are not 2 files in the TEST_DRFA_OUTPUTDIR!"];
}

@end
