//
//  L4PatternLayoutTest.m
//  Log4Cocoa
//
//  Created by Michael James on Wed Mar 03 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "L4PatternLayoutTest.h"
#import <ObjcUnit/ObjcUnit.h>
#import "Log4Cocoa.h"

@implementation L4PatternLayoutTest

- (void)setUp
{
	_pLayout = [[L4PatternLayout alloc] init];
}

- (void)tearDown
{
	if (_pLayout != nil)
	{
		while ([_pLayout retainCount] >= 2)
		{
			[_pLayout release];
		}
		
		[_pLayout release];
		_pLayout = nil;
	}
}

- (void)testCreation
{
	// make sure the layout isn't nil
	[self assertNotNil: _pLayout message: @"_pLayout is nil!"];
	
	// make sure the conversion pattern is %m%n
	[self assertString: [_pLayout conversionPattern] equals: @"%m%n" message: @"conversion pattern isn't nil!"];
	
	// make sure the retain count is 1
	[self assertInt: [_pLayout retainCount] equals: 1 message: @"_pLayout's retain count should be 1 but is not."];
}

- (void)testCreationWithConversionPattern
{
	// get rid of object created in the setUp method and use a different initializer
	[_pLayout release];
	_pLayout = nil;
	
	_pLayout = [[L4PatternLayout alloc] initWithConversionPattern: @"Hello %-20.30C"];
	
	// make sure conversion pattern is not nil
	[self assertNotNil: [_pLayout conversionPattern] message: @"conversion pattern is nil!"];
	
	// make sure conversion pattern is the one we passed in
	[self assertString: [_pLayout conversionPattern] equals: @"Hello %-20.30C" message: @"conversion pattern is not 'Hello %-20.30C'"];
}

- (void)testSetConversionPattern
{
	// make sure conversion pattern is not nil
	[self assertNotNil: [_pLayout conversionPattern] message: @"conversion pattern is nil!"];
	
	[_pLayout setConversionPattern: @"This is a test. %-C"];
	
	// make sure the conversion pattern changed
	[self assertString: [_pLayout conversionPattern] equals: @"This is a test. %-C" message: @"conversion pattern is not 'This is a test. %-C'"];
}

- (void)testFormatWithLiteralStrings
{
	NSString*			actualMessage = nil;
	L4LoggingEvent*		logEvent = nil, *logEvent2 = nil;
	
	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: @"Test message"];
	
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualMessage = [_pLayout format: logEvent];
	
	[self assertString: actualMessage equals: @"Test message" message: @"actualMessage is not 'Test message'"];
	
	logEvent2 = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: @"My 2nd test message!"];
	
	[self assertNotNil: logEvent2 message: @"logEvent2 is nil!"];
	
	[_pLayout setConversionPattern: [logEvent2 message]];
	actualMessage = [_pLayout format: logEvent2];
	
	[self assertString: actualMessage equals: @"My 2nd test message!" message: @"actualMessage is not 'My 2nd test message!'"];
}

- (void)testFormatWithSpecifierC
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%C";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;
	
	ev = [[ExpectationValue alloc] initWithName: @"CSpecifier"];
	
	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];
	
	expectedString = [logger name];
	[ev setExpectedObject: expectedString];
	
	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];
	
	[ev verify];
	
	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCAndNumber
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%C{2}";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;
	NSRange				range;
	NSArray*			expectedSubarray = nil;
	
	ev = [[ExpectationValue alloc] initWithName: @"CAndNumberSpecifier"];
	
	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];
	
	expectedString = [logger name];
	range = NSMakeRange(([[expectedString componentsSeparatedByString: @"."] count] - 2), 2);
	expectedSubarray = [[expectedString componentsSeparatedByString: @"."] subarrayWithRange: range];
	[self assertNotNil: expectedSubarray message: @"expectedSubarray is nil!"];
	
	[ev setExpectedObject: [expectedSubarray componentsJoinedByString: @"."]];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCAndNonNumber
{
	NSString*			formatString = @"%C{gr}";
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	NS_DURING
		[_pLayout setConversionPattern: formatString];
		actualString = [_pLayout format: logEvent];
		[self fail: @"An L4InvalidBraceClauseException should have been thrown, but was not"];
	NS_HANDLER
		[self assertString: [localException name] equals: L4InvalidBraceClauseException];
	NS_ENDHANDLER
}

- (void)testFormatWithSpecifierCAndNegativeNumber
{
	NSString*			formatString = @"%C{-2}";
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	NS_DURING
		[_pLayout setConversionPattern: formatString];
		actualString = [_pLayout format: logEvent];
		[self fail: @"An L4InvalidBraceClauseException should have been thrown, but was not"];
	NS_HANDLER
		[self assertString: [localException name] equals: L4InvalidBraceClauseException];
	NS_ENDHANDLER
}

- (void)testFormatWithSpecifierCLeftJustificationMinWidth
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%-50C";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;
	
	ev = [[ExpectationValue alloc] initWithName: @"CSpecifierWithLeftJustAndMinWidth"];
	
	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];
	
	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];
	
	[ev setExpectedObject: [NSString stringWithFormat: @"%-50s", [expectedString cString]]];
	
	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];
	
	[ev verify];
	
	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCRightJustificationMinWidth
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%50C";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	ev = [[ExpectationValue alloc] initWithName: @"CSpecifierWithRightJustAndMinWidth"];

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];

	[ev setExpectedObject: [NSString stringWithFormat: @"%50s", [expectedString cString]]];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCLeftJustSmallMinWidthMaxWidth
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%-2.50C";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	ev = [[ExpectationValue alloc] initWithName: @"CSpecifierWithLeftJustSmallMinWidthMaxWidth"];

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];

	[ev setExpectedObject: [NSString stringWithFormat: @"%-2.50s", [expectedString cString]]];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCLeftJustSmallMinWidthSmallMaxWidth
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%-2.2C";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	ev = [[ExpectationValue alloc] initWithName: @"CSpecifierWithLeftJustSmallMinWidthSmallMaxWidth"];

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];

	[ev setExpectedObject: [expectedString substringFromIndex: ([expectedString length] - 2)]];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCRightJustSmallMinWidthSmallMaxWidth
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%2.2C";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	ev = [[ExpectationValue alloc] initWithName: @"CSpecifierWithLeftJustSmallMinWidthSmallMaxWidth"];

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];

	[ev setExpectedObject: [expectedString substringFromIndex: ([expectedString length] - 2)]];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCRightJustNoMinWidthSmallMaxWidth
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%.2C";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	ev = [[ExpectationValue alloc] initWithName: @"CSpecifierWithRightJustNoMinWidthSmallMaxWidth"];

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];

	[ev setExpectedObject: [expectedString substringFromIndex: ([expectedString length] - 2)]];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCLeftJustNoMinWidthSmallMaxWidth
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%-.2C";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	ev = [[ExpectationValue alloc] initWithName: @"CSpecifierWithLeftJustNoMinWidthSmallMaxWidth"];

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];

	[ev setExpectedObject: [expectedString substringFromIndex: ([expectedString length] - 2)]];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCLeftJustSmallMinWidthNoMaxWidth
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"%-10.C";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	ev = [[ExpectationValue alloc] initWithName: @"CSpecifierWithLeftJustNoMinWidthSmallMaxWidth"];

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];

	[ev setExpectedObject: [NSString stringWithFormat: @"%-10s", [expectedString cString]]];
	
	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWithSpecifierCTextBeforeAndAfter
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"Text before %-10.11C text after";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	ev = [[ExpectationValue alloc] initWithName: @"CSpecifierWithTextBeforeAndAfter"];

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];

	[ev setExpectedObject: [NSString stringWithFormat: @"Text before %-10.11s text after", [[expectedString substringFromIndex: ([expectedString length] - 11)] cString]]];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWith2SpecifiersCTextBeforeAndAfter
{
	ExpectationValue*	ev = nil;
	NSString*			formatString = @"Text before %-10.11C text between %C text after";
	NSString*			expectedString = nil;
	NSString*			actualString = nil;
	L4LoggingEvent*		logEvent = nil;
	L4Logger*			logger = nil;

	ev = [[ExpectationValue alloc] initWithName: @"2CSpecifiersWithTextBeforeAndAfter"];

	logger = [L4Logger loggerForClass: [_pLayout class]];
	[self assertNotNil: logger message: @"logger is nil!"];

	expectedString = [logger name];
	[self assertNotNil: expectedString message: @"expectedString is nil!"];

	[ev setExpectedObject: [NSString stringWithFormat: @"Text before %-10.11s text between %s text after", [[expectedString substringFromIndex: ([expectedString length] - 11)] cString], [expectedString cString]]];

	logEvent = [L4LoggingEvent logger: logger level: [L4Level debug] message: formatString];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: [logEvent message]];
	actualString = [_pLayout format: logEvent];
	[ev setActualObject: actualString];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testFormatWithIncorrectSpecifier
{
	NSString*		formatString = @"This is incorrect. %";
	L4LoggingEvent*	logEvent = nil;
	
	NS_DURING
		logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: formatString];
		[self assertNotNil: logEvent message: @"logEvent is nil!"];
		
		[_pLayout setConversionPattern: [logEvent message]];
		[_pLayout format: logEvent];
		[self fail: @"Expected an L4InvalidSpecifierException, but no exception was thrown"];
	NS_HANDLER
		if (![[localException name] isEqualToString: L4InvalidSpecifierException])
		{
			[self fail: [NSString stringWithFormat: @"Expected an L4InvalidSpecifierException, but an exception of type %@ was thrown", [localException name]]];
			[localException raise];
		}
	NS_ENDHANDLER
}

/*
- (void)testFormatWithNoConversionPattern
{
	L4LoggingEvent*	logEvent = nil;
	
	NS_DURING
		logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
		[self assertNotNil: logEvent message: @"logEvent is nil!"];
		
		[_pLayout format: logEvent];
		[self fail: @"Expected an L4NoConversionPatternException, but no exception was thrown"];
	NS_HANDLER
		if (![[localException name] isEqualToString: L4NoConversionPatternException])
		{
			[self fail: [NSString stringWithFormat: @"Expected an L4NoConversionPatternException, but an exception of type %@ was thrown", [localException name]]];
			[localException raise];
		}
	NS_ENDHANDLER
}
*/

- (void)testParseConversionPatternIntoArray
{
	NSString*			formatString = @"This is a test: %10.30C{1}";
	NSMutableArray*		tokenArray = nil;
	ExpectationList*	el = nil;
	int					index = -1;
	
	tokenArray = [NSMutableArray arrayWithCapacity: 3];
	el = [[ExpectationList alloc] initWithName: @"Conversion Pattern Parser Results"];
	
	[_pLayout parseConversionPattern: formatString intoArray: &tokenArray];
	
	[el addExpectedObject: @"This is a test: "];
	[el addExpectedObject: @"%10.30C{1}"];
	
	for (index = 0; index < [tokenArray count]; index++)
	{
		[el addActualObject: [tokenArray objectAtIndex: index]];
	}
	
	[el verify];
	
	[el release];
	el = nil;
}

- (void)testConvertTokenStringWithConstantStrings
{
	NSString*			tokenString = nil;
	L4LoggingEvent*		logEvent = nil;
	NSString*			actualResult = nil;
	BOOL				returnValue;
	ExpectationValue*	ev = nil;
	
	ev = [[ExpectationValue alloc] initWithName: @"Conversion Pattern Converter Results"];
	
	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	tokenString = @"This is a test!";
	
	[ev setExpectedObject: @"This is a test!"];
	
	returnValue = [_pLayout convertTokenString: tokenString withLoggingEvent: logEvent intoString: &actualResult];
	[self assertTrue: returnValue message: @"convertTokenString:withLoggingEvent:intoString: returned NO!"];
	
	[ev setActualObject: actualResult];
	
	[ev verify];
	
	tokenString = @"Testing, testing, 1 2 3...";
	
	[ev setExpectedObject: @"Testing, testing, 1 2 3..."];

	returnValue = [_pLayout convertTokenString: tokenString withLoggingEvent: logEvent intoString: &actualResult];
	[self assertTrue: returnValue message: @"convertTokenString:withLoggingEvent:intoString: returned NO!"];
	
	[ev setActualObject: actualResult];
	
	[ev verify];
	
	[ev release];
	ev = nil;
}

- (void)testSpecifierdWithCustomFormat
{
	NSString*			tokenString = @"%d{%a %m/%d/%y %I:%M %p}";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;
	
	ev = [[ExpectationValue alloc] initWithName: @"Specifier d results"];
	
	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];
	
	[_pLayout setConversionPattern: tokenString];
	
	[ev setExpectedObject: [[logEvent timestamp] descriptionWithCalendarFormat: @"%a %m/%d/%y %I:%M %p"]];
	[ev setActualObject: [_pLayout format: logEvent]];
	
	[ev verify];
	
	[ev release];
	ev = nil;
}

- (void)testSpecifierd
{
	NSString*			tokenString = @"%d";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier d results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: [[logEvent timestamp] description]];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testSpecifierF
{
	NSString*			tokenString = @"%F";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier F results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: [logEvent fileName]];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testSpecifierl
{
	NSString*			tokenString = @"%l";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier l results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: [NSString stringWithFormat: @"%@'s %@ (%@:%d)", [[logEvent logger] name], [logEvent methodName], [logEvent fileName], [[logEvent lineNumber] intValue] ]];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testSpecifierL
{
	NSString*			tokenString = @"%L";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier L results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: [NSString stringWithFormat: @"%d", [[logEvent lineNumber] intValue] ]];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testSpecifierm
{
	NSString*			tokenString = @"%m";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier m results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: @"This is a test message!"];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: @"This is a test message!"];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testSpecifierM
{
	NSString*			tokenString = @"%M";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier M results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: [logEvent methodName]];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testSpecifiern
{
	NSString*			tokenString = @"%n";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier n results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: @"\n"];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testSpecifierp
{
	NSString*			tokenString = @"%p";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier p results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: @"DEBUG"];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testSpecifierr
{
	NSString*			tokenString = @"%r";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier r results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: [NSString stringWithFormat: @"%d", [logEvent millisSinceStart] ]];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

- (void)testSpecifierPercentSign
{
	NSString*			tokenString = @"%%";
	ExpectationValue*	ev = nil;
	L4LoggingEvent*		logEvent = nil;

	ev = [[ExpectationValue alloc] initWithName: @"Specifier % results"];

	logEvent = [L4LoggingEvent logger: [L4Logger loggerForClass: [_pLayout class]] level: [L4Level debug] message: nil];
	[self assertNotNil: logEvent message: @"logEvent is nil!"];

	[_pLayout setConversionPattern: tokenString];

	[ev setExpectedObject: @"%"];
	[ev setActualObject: [_pLayout format: logEvent]];

	[ev verify];

	[ev release];
	ev = nil;
}

@end
