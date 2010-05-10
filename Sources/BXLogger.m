//
// BXLogger.m
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


#import "BXLogger.h"
#import <dlfcn.h>
#import <unistd.h>

enum BXLogLevel BXLogLevel = kBXLogLevelWarning;


void BXSetLogLevel (enum BXLogLevel level)
{
	BXLogLevel = level;
}

static inline const char* LogLevel (enum BXLogLevel level)
{
	char* retval = NULL;
	switch (level)
	{
		case kBXLogLevelDebug:
			retval = "DEBUG:";
			break;
		
		case kBXLogLevelInfo:
			retval = "INFO:";
			break;
		
		case kBXLogLevelWarning:
			retval = "WARNING:";
			break;
			
		case kBXLogLevelError:
			retval = "ERROR:";
			break;
		
		case kBXLogLevelOff:
		case kBXLogLevelFatal:
		default:
			retval = "FATAL:";
			break;
	}
	return retval;
}

static inline const char* LastPathComponent (const char* path)
{
	const char* retval = ((strrchr (path, '/') ?: path - 1) + 1);
	return retval;
}

static char* CopyLibraryName (const void* addr)
{
	Dl_info info = {};
	char* retval = NULL;
	if (dladdr (addr, &info))
		retval = strdup (LastPathComponent (info.dli_fname));
	return retval;
}

static char* CopyExecutableName ()
{
	uint32_t pathLength = 0;
	_NSGetExecutablePath (NULL, &pathLength);
	char* path = malloc (pathLength);
	char* retval = NULL;
	if (path)
	{
		if (0 == _NSGetExecutablePath (path, &pathLength))
			retval = strdup (LastPathComponent (path));

		free (path);
	}
	return retval;
}

void BXAssertionDebug ()
{
	BXLogError (@"Break on BXAssertionDebug to inspect.");
}

void
BXDeprecationWarning ()
{
	BXLogError (@"Break on BXDeprecationWarning to inspect.");
}

void BXLog (const char* fileName, const char* functionName, void* functionAddress, int line, enum BXLogLevel level, id messageFmt, ...)
{
	va_list args;
    va_start (args, messageFmt);
	BXLog_v (fileName, functionName, functionAddress, line, level, messageFmt, args);
	va_end (args);
}

void BXLog_v (const char* fileName, const char* functionName, void* functionAddress, int line, enum BXLogLevel level, id messageFmt, va_list args)
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	char* executable = CopyExecutableName ();
	char* library = CopyLibraryName (functionAddress);
	const char* file = LastPathComponent (fileName);
	
	NSString* date = [[NSDate date] descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S.%F" timeZone: nil locale: nil];
	NSString* message = [[[NSString alloc] initWithFormat: messageFmt arguments: args] autorelease];
		
	const char isMain = ([NSThread isMainThread] ? 'm' : 's');
	fprintf (stderr, "%23s  %s (%s) [%d]  %s:%d  %s [%p%c] \t%8s %s\n", 
		[date UTF8String], executable, library ?: "???", getpid (), file, line, functionName, [NSThread currentThread], isMain, LogLevel (level), [message UTF8String]);
	
	//For GC.
	[date self];
	[message self];
	
	if (executable)
		free (executable);
	if (library)
		free (library);
	[pool drain];
}
