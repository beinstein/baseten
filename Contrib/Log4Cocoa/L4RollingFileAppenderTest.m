//
//  L4RollingFileAppenderTest.m
//  Log4Cocoa
//
//  Created by Michael James on Wed Apr 28 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "L4RollingFileAppenderTest.h"
#import "L4RollingFileAppender.h"
#import "L4PatternLayout.h"

#define TEST_RFA_LOG_OUTPUTFILE1 [@"~/Desktop/testRollingFileAppenderLogOutputFile1" stringByExpandingTildeInPath]
#define TEST_RFA_LOG_OUTPUTFILE2 [@"~/Desktop/testRollingFileAppenderLogOutputFile1.1" stringByExpandingTildeInPath]
#define TEST_RFA_LOG_OUTPUTFILE3 [@"~/Desktop/testRollingFileAppenderLogOutputFile1.2" stringByExpandingTildeInPath]

@implementation L4RollingFileAppenderTest

- (void)setUp
{
	_rfa = [[L4RollingFileAppender alloc] initWithLayout: nil fileName: TEST_RFA_LOG_OUTPUTFILE1];
}

- (void)tearDown
{
	NSFileManager*	fm = [NSFileManager defaultManager];
	
	[fm removeFileAtPath: TEST_RFA_LOG_OUTPUTFILE1 handler: nil];
	[fm removeFileAtPath: TEST_RFA_LOG_OUTPUTFILE2 handler: nil];
	[fm removeFileAtPath: TEST_RFA_LOG_OUTPUTFILE3 handler: nil];	
	
	[[self l4Logger] removeAppender: _rfa];
	
	[_rfa release];
	_rfa = nil;
}

- (void)testCreation
{
	[self assertNotNil: _rfa message: @"_rfa is nil!"];
	[self assertInt: [_rfa maxBackupIndex] equals: 1 message: @"_rfa's default maxBackupIndex is not 1!"];
	[self assertTrue: ([_rfa maximumFileSize] == kL4RollingFileAppenderDefaultMaxFileSize) message: @"_rfa's default maximum file size is not 10MB!"];
}

- (void)testRollover
{
	L4PatternLayout*	pl = nil;
	NSFileManager*		fm = [NSFileManager defaultManager];
	
	pl = [[[L4PatternLayout alloc] initWithConversionPattern: @"%m"] autorelease];
	[_rfa setLayout: pl];
	[self assert: [_rfa layout] same: pl message: @"setLayout failed!"];
	
	[_rfa setMaxBackupIndex: 1];
	[self assertInt: [_rfa maxBackupIndex] equals: 1 message: @"setMaxBackupIndex is not 1!"];
	
	[_rfa setMaximumFileSize: 10];
	[self assertInt: [_rfa maximumFileSize] equals: 10 message: @"setMaximumFileSize is not 10!"];
	
	[[self l4Logger] addAppender: _rfa];
	log4Debug(@"This is a rolling file test for the first file!", nil);
	log4Debug(@"This is a rolling file test for the second file!", nil);
	
	[self assertTrue: [fm fileExistsAtPath: TEST_RFA_LOG_OUTPUTFILE1] message: @" ~/Desktop/testRollingFileAppenderLogOutputFile1 doesn't exist!"];
	[self assertTrue: [fm fileExistsAtPath: TEST_RFA_LOG_OUTPUTFILE2] message: @"~/Desktop/testRollingFileAppenderLogOutputFile1.1 doesn't exist!"];
	
	[self assert: [NSString stringWithContentsOfFile: TEST_RFA_LOG_OUTPUTFILE1] equals: @"This is a rolling file test for the second file!\n" message: @"Contents of TEST_RFA_LOG_OUTPUTFILE1 is incorrect!"];
	[self assert: [NSString stringWithContentsOfFile: TEST_RFA_LOG_OUTPUTFILE2] equals: @"This is a rolling file test for the first file!\n" message: @"Contents of TEST_RFA_LOG_OUTPUTFILE2 is incorrect!"];
	
	log4Debug(@"This is a rolling file test for the third file!", nil);

	[self assertTrue: [fm fileExistsAtPath: TEST_RFA_LOG_OUTPUTFILE1] message: @" ~/Desktop/testRollingFileAppenderLogOutputFile1 doesn't exist!"];
	[self assertTrue: [fm fileExistsAtPath: TEST_RFA_LOG_OUTPUTFILE2] message: @"~/Desktop/testRollingFileAppenderLogOutputFile1.1 doesn't exist!"];

	[self assert: [NSString stringWithContentsOfFile: TEST_RFA_LOG_OUTPUTFILE1] equals: @"This is a rolling file test for the third file!\n" message: @"Contents of TEST_RFA_LOG_OUTPUTFILE1 is incorrect!"];
	[self assert: [NSString stringWithContentsOfFile: TEST_RFA_LOG_OUTPUTFILE2] equals: @"This is a rolling file test for the second file!\n" message: @"Contents of TEST_RFA_LOG_OUTPUTFILE2 is incorrect!"];
}

@end
