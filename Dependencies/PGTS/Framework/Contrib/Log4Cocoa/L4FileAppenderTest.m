//
//  L4FileAppenderTest.m
//  Log4Cocoa
//
//  Created by Michael James on Tue Apr 27 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "L4FileAppenderTest.h"

#import "Log4Cocoa.h"

#define TEST_FA_LOG_OUTPUTFILE1 [@"~/Desktop/testFileAppenderLogOutputFile1" stringByExpandingTildeInPath]

@implementation L4FileAppenderTest

- (void)setUp
{
	_fileAppender = [[L4FileAppender alloc] init];
}

- (void)tearDown
{
	NSFileManager*	fm = [NSFileManager defaultManager];
	
	[[L4LogManager l4Logger] removeAppender: _fileAppender];
	
	[_fileAppender release];
	_fileAppender = nil;
	
	if ([fm fileExistsAtPath: TEST_FA_LOG_OUTPUTFILE1])
	{
		[fm removeFileAtPath: TEST_FA_LOG_OUTPUTFILE1 handler: nil];
	}
}

- (void)testCreation
{
	[self assertNotNil: _fileAppender message: @"_fileAppender is nil!"];
}

- (void)testBufferedIO
{
	[self assertFalse: [_fileAppender bufferedIO] message: @"_fileAppender is set to buffer IO!"];
}

- (void)testBufferSize0
{
	[self assertInt: [_fileAppender bufferSize] equals: 0 message: @"_fileAppender's bufferSize is not 0!"];
}

- (void)testSetFileName
{
	[self assertNil: [_fileAppender fileName] message: @"_fileAppender's fileName is not nil!"];
	[_fileAppender setFileName: TEST_FA_LOG_OUTPUTFILE1];
	[_fileAppender activateOptions];
	[self assert: [_fileAppender fileName] equals: TEST_FA_LOG_OUTPUTFILE1 message: @"_fileAppender's fileName is not ~/Desktop/testLogOutputFile1!"];
	[self assertTrue: [[NSFileManager defaultManager] isWritableFileAtPath: [_fileAppender fileName]] message: @"cannot find a writable file named testLogOutputFile1!"];
}

- (void)testLogging
{
	NSString*			messageString = nil;
	L4PatternLayout*	pl = nil;
	
	pl = [[[L4PatternLayout alloc] initWithConversionPattern: @"%m"] autorelease];
	
	[_fileAppender setFileName: TEST_FA_LOG_OUTPUTFILE1];
	[_fileAppender setLayout: pl];
	[_fileAppender activateOptions];
	[[self l4Logger] addAppender: _fileAppender];
	log4Debug(@"This is a debug message!", nil);
	
	messageString = [NSString stringWithContentsOfFile: TEST_FA_LOG_OUTPUTFILE1];
	[self assert: messageString equals: @"This is a debug message!\n" message: @"messageString is not 'This is a debug message!\\n'"];
}

@end
