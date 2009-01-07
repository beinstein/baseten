//
// BXDataModelCompiler.m
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


#import "BXDataModelCompiler.h"
#import "BXLogger.h"
#import "BXEnumerate.h"


@implementation BXDataModelCompiler
+ (NSString *) momcPath
{
	__strong static NSString* momcPath = nil;
	if (! momcPath)
	{
		NSFileManager* manager = [NSFileManager defaultManager];
		
		//Paths inside the system developer directory which may lead to momc.
		NSArray* developerSubpaths = [NSArray arrayWithObjects: 
									  @"/usr/bin/momc", 
									  @"/Library/Xcode/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc", 
									  nil];
		
		
		//Try using xcode-select's setting.
		{
			int fd = open ("/usr/share/xcode-select/xcode_dir_path", O_RDONLY | O_SHLOCK);
			FILE* file = fdopen (fd, "r");
			if (file)
			{
				char buffer [1024] = {};
				if (fgets (buffer, 1024, file))
				{
					//Remove the newline character if one exists.
					size_t length = strlen (buffer);
					if ('\n' == buffer [length - 1])
						buffer [length - 1] = '\0';
					
					BXEnumerate (currentSubpath, e, [developerSubpaths objectEnumerator])
					{
						NSString* path = [NSString stringWithFormat: @"%s%@", buffer, currentSubpath];
						if ([manager fileExistsAtPath: path])
						{
							momcPath = [path retain];
							fclose (file);
							goto end;
						}
					}
				}
			}
			fclose (file);
		}
		
		//Try using paths from NSSearchPathForDirectoriesInDomains 
		//(which returns always /Developer and not xcode-select's setting).
		{
			NSArray* paths = NSSearchPathForDirectoriesInDomains (NSDeveloperDirectory, NSAllDomainsMask, YES);
			BXEnumerate (currentPath, e, [paths objectEnumerator])
			{
				BXEnumerate (currentSubpath, e, [developerSubpaths objectEnumerator])
				{
					NSString* path = [currentPath stringByAppendingString: currentSubpath];
					if ([manager fileExistsAtPath: path])
					{
						momcPath = [path retain];
						goto end;
					}
				}
			}
		}
		
		//Finally try something rather old.
		{
			NSString* path = @"/Library/Application Support/Apple/Developer Tools/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc";
			if ([manager fileExistsAtPath: path])
			{
				momcPath = [path retain];
				goto end;
			}
		}
	}
end:
	return momcPath;
}

- (void) dealloc
{
	[mModelURL release];
	[mCompiledModelURL release];
	[mMomcTask release];
	[mErrorPipe release];
	[super dealloc];
}

- (void) setDelegate: (id <BXDataModelCompilerDelegate>) anObject
{
	mDelegate = anObject;
}

- (void) setModelURL: (NSURL *) aFileURL
{
	if (mModelURL != aFileURL)
	{
		[mModelURL release];
		mModelURL = [aFileURL retain];
	}
}

- (void) setCompiledModelURL: (NSURL *) aFileURL
{
	if (mCompiledModelURL != aFileURL)
	{
		[mCompiledModelURL release];
		mCompiledModelURL = [aFileURL retain];
	}
}

- (NSURL *) compiledModelURL
{
	return mCompiledModelURL;
}

- (void) compileDataModel
{
	//FIXME: handle errors in asprintf and mkstemps.
	
	NSString* sourcePath = [mModelURL path];
	char* pathFormat = NULL;
	BOOL ok = NO;
	if ([sourcePath hasSuffix: @".xcdatamodeld"])
	{
		asprintf (&pathFormat, "%s/BaseTen.datamodel.%u.XXXXX", 
				  [NSTemporaryDirectory () UTF8String], getpid ());
		ok = (NULL != mkdtemp (pathFormat));
	}
	else
	{
		asprintf (&pathFormat, "%s/BaseTen.datamodel.%u.XXXXX.mom", 
				  [NSTemporaryDirectory () UTF8String], getpid ());
		ok = (-1 != mkstemps (pathFormat, 5));
	}
	
	if (ok)
	{
		NSString* targetPath = [NSString stringWithCString: pathFormat encoding: NSUTF8StringEncoding];
		NSString* momcPath = [[self class] momcPath];
		NSArray* arguments = [NSArray arrayWithObjects: sourcePath, targetPath, nil];
		[self setCompiledModelURL: [NSURL fileURLWithPath: targetPath]];
		mErrorPipe = [[NSPipe pipe] retain];
		
		mMomcTask = [[NSTask alloc] init];
		[mMomcTask setLaunchPath: momcPath];
		[mMomcTask setArguments: arguments];
		[mMomcTask setStandardError: [mErrorPipe fileHandleForWriting]];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector (momcTaskFinished:) 
													 name: NSTaskDidTerminateNotification object: mMomcTask];
		[mMomcTask launch];
	}
	
	if (pathFormat)
		free (pathFormat);
}

- (void) momcTaskFinished: (NSNotification *) notification
{
	[mDelegate dataModelCompiler: self finished: [mMomcTask terminationStatus] errorOutput: [mErrorPipe fileHandleForReading]];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[mMomcTask release];
	mMomcTask = nil;
	[mErrorPipe release];
	mErrorPipe = nil;
}
@end
