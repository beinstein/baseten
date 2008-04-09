/****************************
*
* Copyright (c) 2002, 2003, Bob Frank
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
*
*  - Redistributions of source code must retain the above copyright
*    notice, this list of conditions and the following disclaimer.
*
*  - Redistributions in binary form must reproduce the above copyright
*    notice, this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution.
*
*  - Neither the name of Log4Cocoa nor the names of its contributors or owners
*    may be used to endorse or promote products derived from this software
*    without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
* A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
****************************/

#import "L4Configurator.h"
#import "L4Logger.h"
#import "L4Level.h"
#import "L4ConsoleAppender.h"
#import "L4Layout.h"
#import <stdlib.h>

NSString* const L4ConfigurationFilePath = @"L4ConfigurationFilePath";
NSString* const L4ConfigurationFileName = @"Log4CocoaConfiguration";

static NSData *lineBreakChar = nil;
static NSRecursiveLock *configurationLock = nil;
static volatile BOOL haveConfiguration = NO;

@implementation L4Configurator

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (NO == tooLate)
	{
		tooLate = YES;
		
		// Making sure that we capture the startup time of
		// this application.  This sanity check is also in
		// +[L4Logger initialize] too.
		//
		[L4LoggingEvent startTime];
		
		configurationLock = [[NSRecursiveLock alloc] init];
	}
}

+ (void) basicConfiguration
{
	[configurationLock lock];
	if (NO == haveConfiguration)
	{
		L4Logger* rootLogger = [L4Logger rootLogger];
		id appender = [[[L4ConsoleAppender alloc] initStandardOutWithLayout: [L4Layout simpleLayout]] autorelease];
		[rootLogger addAppender: appender];
#if defined(RELEASE_BUILD)
		[rootLogger setLevel: [L4Level error]];
#else
		[rootLogger setLevel: [L4Level info]];
#endif
		
		haveConfiguration = YES;
	}
	[configurationLock unlock];
}

+ (void) autoConfigure
{
	[configurationLock lock];
	if (NO == haveConfiguration)
	{		
		// [[NSFileManager defaultManager] currentDirectoryPath];
		NSString* path = [self configurationFilePath];
		if (nil == path)
			[self basicConfiguration];
		else
		{
			L4Logger* rootLogger = [L4Logger rootLogger];
			NSDictionary* configuration = [NSDictionary dictionaryWithContentsOfFile: path];
			[rootLogger parseConfiguration: [configuration objectForKey: @"DefaultConfiguration"]];
			
			//Add a basic appender in case one wasn't configured
			if (0 < [[rootLogger allAppendersArray] count])
				[self basicConfiguration];
			
			NSEnumerator* e = nil;
			id currentKey = nil;
			NSDictionary* dict = nil;
			
			{
				dict = [configuration objectForKey: @"ConfigurationByClass"];
				e = [dict keyEnumerator];
				while ((currentKey = [e nextObject]))
				{
					L4Logger* logger = [L4Logger loggerForClass: NSClassFromString (currentKey)];
					[logger parseConfiguration: [dict objectForKey: currentKey]];
				}
			}
			
			{
				dict = [configuration objectForKey: @"ConfigurationByName"];
				e = [dict keyEnumerator];
				while ((currentKey = [e nextObject]))
				{
					L4Logger* logger = [L4Logger loggerForName: currentKey];
					[logger parseConfiguration: [dict objectForKey: currentKey]];
				}
			}
		}
		haveConfiguration = YES;
	}
	[configurationLock unlock];
}

/**
 * Look up a configuration file.
 * First check an environment variable, then the user defaults and finally the resources folder.
 */
+ (NSString *) configurationFilePath
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* path = nil;
    
    char* envPath = getenv ("Log4CocoaConfigurationFile");
    if (NULL != envPath)
    {
        path = [NSString stringWithUTF8String: envPath];
        if (nil != path && [fm fileExistsAtPath: path])
            return path;
    }
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    path = [defaults objectForKey: L4ConfigurationFilePath];
    if (nil != path && [fm fileExistsAtPath: path])
        return path;
    
    path = [[NSBundle mainBundle] pathForResource: L4ConfigurationFileName ofType: @"plist"];
    
    return path;
}

+ (id) propertyForKey: (NSString *) aKey
{
    return nil;
}

+ (void) resetLineBreakChar
{
    [lineBreakChar autorelease];
    lineBreakChar = nil;
}

+ (NSData *) lineBreakChar
{
    if( lineBreakChar == nil )
    {
        id breakChar = [self propertyForKey: LINE_BREAK_SEPERATOR_KEY];
        if( breakChar != nil )
        {
            lineBreakChar = [[breakChar dataUsingEncoding: NSASCIIStringEncoding
                                     allowLossyConversion: YES] retain];
        }
        else
        {
            // DEFAULT VALUE
            lineBreakChar = [[@"\n" dataUsingEncoding: NSASCIIStringEncoding
                                 allowLossyConversion: YES] retain];
        }
    }

    return lineBreakChar;
}

@end
