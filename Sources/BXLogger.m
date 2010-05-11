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
static BOOL stAbortOnAssertionFailure = NO;
// If the log file will be larger than this amount of bytes then it'll be truncated
static const unsigned long long kLogFileMaxSize = 1024 * 1024;
// When the log file will be truncated, this amount of bytes will be left to the beginning of the file
static const unsigned long long kLogFileTruncateSize = 1024 * 128; 


static void TruncateLogFile (NSString *filePath)
{
	NSFileManager *fm = [[NSFileManager alloc] init];
	if ([fm fileExistsAtPath: filePath])
	{
		NSNumber *sizeAttr = nil;
		NSError *error = nil;
		if ([fm respondsToSelector: @selector (attributesOfItemAtPath:error:)])
			sizeAttr = [[fm attributesOfItemAtPath: filePath error: &error] objectForKey: NSFileSize];
		else
			sizeAttr = [[fm fileAttributesAtPath: filePath traverseLink: NO] objectForKey: NSFileSize];
		
		if (sizeAttr)
		{
			unsigned long long fileSize = [sizeAttr unsignedLongLongValue];
			if (kLogFileMaxSize < fileSize)
			{
				NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath: filePath];
				[fileHandle seekToFileOffset: (fileSize - kLogFileTruncateSize)];
				NSData *dataToLeave = [fileHandle readDataToEndOfFile];
				
				[fileHandle seekToFileOffset: 0];
				[fileHandle writeData: dataToLeave];
				[fileHandle truncateFileAtOffset: kLogFileTruncateSize];
				[fileHandle synchronizeFile];
				[fileHandle closeFile];
			}
		}
		else if (error)
		{
			BXLogError (@"Couldn't get attributes of file at path '%@', error: '%@'.", filePath, error);
		}
		else
		{
			BXLogError (@"Couldn't get attributes of file at path '%@'.", filePath);
		}
	}	
	[fm release];
}


static inline
const char* LogLevel (enum BXLogLevel level)
{
	const char* retval = NULL;
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


static inline
const char* LastPathComponent (const char* path)
{
	const char* retval = ((strrchr (path, '/') ?: path - 1) + 1);
	return retval;
}


static char*
CopyLibraryName (const void* addr)
{
	Dl_info info = {};
	char* retval = NULL;
	if (dladdr (addr, &info))
		retval = strdup (LastPathComponent (info.dli_fname));
	return retval;
}


static char*
CopyExecutableName ()
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


void
BXLogSetLogFile (NSBundle *bundle)
{
    FSRef fileRef = {};
    OSErr err = FSFindFolder (kUserDomain, kLogsFolderType, (Boolean) YES, &fileRef);
	if (noErr == err)
	{
		CFURLRef URL = CFURLCreateFromFSRef (kCFAllocatorSystemDefault, &fileRef);
		CFStringRef logsFolder = CFURLCopyFileSystemPath (URL, kCFURLPOSIXPathStyle);
		NSString *bundleName = [bundle objectForInfoDictionaryKey: (NSString *) kCFBundleNameKey];
		NSString *logPath = [NSString stringWithFormat: @"%@/%@.%@", logsFolder, bundleName, @"log"];
		
		if (freopen ([logPath fileSystemRepresentation], "a", stderr))
			TruncateLogFile (logPath);		
		else
		{
			BXLogError (@"Couldn't redirect stderr stream to file at path '%@', errno: %d, error: '%s'.", 
						logPath, errno, strerror (errno));
		}
		
		if (logsFolder) 
			CFRelease (logsFolder);
		if (URL)
			CFRelease (URL);
	}
	else
	{
		BXLogError (@"Unable to get logs folder in the user domain: %s.",
					GetMacOSStatusCommentString (err));
	}
}


void BXSetLogLevel (enum BXLogLevel level)
{
	BXDeprecationLog ();
	BXLogLevel = level;
}


void BXLogSetLevel (enum BXLogLevel level)
{
	BXLogLevel = level;
}


void BXLogSetAbortsOnAssertionFailure (BOOL flag)
{
	stAbortOnAssertionFailure = flag;
}


void
BXAssertionDebug ()
{
	if (stAbortOnAssertionFailure)
		abort ();
	else
		BXLogError (@"Break on BXAssertionDebug to inspect.");
}


void
BXDeprecationWarning ()
{
	BXLogError (@"Break on BXDeprecationWarning to inspect.");
}


void
BXLog (const char* fileName, const char* functionName, void* functionAddress, int line, enum BXLogLevel level, id messageFmt, ...)
{
	va_list args;
    va_start (args, messageFmt);
	BXLog_v (fileName, functionName, functionAddress, line, level, messageFmt, args);
	va_end (args);
}


void
BXLog_v (const char* fileName, const char* functionName, void* functionAddress, int line, enum BXLogLevel level, id messageFmt, va_list args)
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
