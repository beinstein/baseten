//
// BXPGSQLScriptReader.m
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

#import <SQLParser/BXPGSQLScanner.h>
#import <sys/stat.h>

#import "PGTS.h"
#import "BXPGSQLScriptReader.h"
#import "BXPGAdditions.h"


@interface BXPGSQLScriptReader (BXPGSQLScannerDelegate) <BXPGSQLScannerDelegate>
@end


@implementation BXPGSQLScriptReader
- (void) setConnection: (PGTSConnection *) connection
{
	if (connection != mConnection)
	{
		[mConnection release];
		mConnection = [connection retain];
	}
}

- (void) setScanner: (BXPGSQLScanner *) scanner
{
	if (scanner != mScanner)
	{
		[mScanner release];
		mScanner = [scanner retain];
	}
}

- (BOOL) openFileAtURL: (NSURL *) fileURL
{
	BOOL retval = NO;
	if (mFile)
	{
		fclose (mFile);
		mFile = NULL;
	}
	
	NSString* pathString = [fileURL path];
	const char* path = [pathString UTF8String];
	int fd = open (path, O_RDONLY | O_SHLOCK);
	struct stat statbuf = {};
	if (-1 != fstat (fd, &statbuf))
	{
		mFileSize = statbuf.st_size;
		mFile = fdopen (fd, "r");
		if (mFile)
			retval = YES;
	}
	
	//For GC.
	[pathString self];
	return retval;
}

- (off_t) length
{
	return mFileSize;
}
   
- (void) readAndExecute
{
	ExpectV (mFile);
	ExpectV (mConnection);

	if (! mScanner)
	{
		mScanner = [[BXPGSQLScanner alloc] init];
		[mScanner setDelegate: self];
	}
	
	[mScanner continueScanning];
}


- (void) readAndExecuteAsynchronously
{
	mAsynchronous = YES;
	[self readAndExecute];
}


- (void) readAndExecuteSynchronously
{
	mAsynchronous = NO;
	[self readAndExecute];
}


- (void) scriptEnded
{
	mCanceling = NO;
	if (mFile)
		fclose (mFile);
}


- (void) performEndSelector: (BOOL) succeeded resultSet: (PGTSResultSet *) res
{
	SEL selector = @selector (SQLScriptReader:failed:userInfo:);
	if (succeeded)
		selector = @selector (SQLScriptReaderSucceeded:userInfo:);
	
	NSMethodSignature* sig = [(NSObject *) mDelegate methodSignatureForSelector: selector];
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
	[invocation setTarget: mDelegate];
	[invocation setSelector: selector];
	[invocation setArgument: &self atIndex: 2];
	
	int next = 3;
	if (! succeeded)
	{
		[invocation setArgument: &res atIndex: 3];
		next++;
	}
	[invocation setArgument: &mDelegateUserInfo atIndex: next];
	[invocation invoke];
}


- (void) receivedResult: (PGTSResultSet *) res
{
	if (! mCanceling && (mIgnoresErrors || [res querySucceeded]))
		[mScanner continueScanning];
	else
	{
		[mConnection executeQuery: @"ROLLBACK;"];
		[self performEndSelector: NO resultSet: res];
		[self scriptEnded];
	}
}


- (void) dealloc
{
	if (mFile)
		fclose (mFile);
	[mScanner release];
	[mConnection release];
	[mDelegateUserInfo release];
	[super dealloc];
}

- (void) finalize
{
	if (mFile)
		fclose (mFile);
	[super finalize];
}

- (void) setDelegate: (id <BXPGSQLScriptReaderDelegate>) anObject
{
	mDelegate = anObject;
}

- (void) setDelegateUserInfo: (id) anObject
{
	if (mDelegateUserInfo != anObject)
	{
		[mDelegateUserInfo release];
		mDelegateUserInfo = [anObject retain];
	}
}

- (id) delegateUserInfo
{
	return mDelegateUserInfo;
}

- (void) cancel
{
	mCanceling = YES;
}

- (void) setIgnoresErrors: (BOOL) flag
{
	mIgnoresErrors = flag;
}
@end


@implementation BXPGSQLScriptReader (BXPGSQLScannerDelegate)
- (const char *) nextLineForScanner: (BXPGSQLScanner *) scanner
{
	const char* retval = fgets (mBuffer, BXPGSQLScannerBufferSize, mFile);

	off_t pos = ftello (mFile);
	[mDelegate SQLScriptReader: self advancedToPosition: pos userInfo: mDelegateUserInfo];

	if (! retval)
	{
		[self performEndSelector: YES resultSet: nil];
		[self scriptEnded];
	}
	return retval;
}

- (void) scanner: (BXPGSQLScanner *) scanner scannedQuery: (NSString *) query complete: (BOOL) isComplete
{
	if (isComplete)
	{
		if (mAsynchronous)
			[mConnection sendQuery: query delegate: self callback: @selector (receivedResult:)];
		else
		{
			//Mutual recursion is used quite a lot here. With large SQL files 
			//tail recursion (sibling call) optimization might be needed.
			
			PGTSResultSet* res = [mConnection executeQuery: query];
			[self receivedResult: res];
		}
	}
}

- (void) scanner: (BXPGSQLScanner *) scanner scannedCommand: (NSString *) command options: (NSString *) options
{
	//We only recognize \set and \unset with ON_ERROR_STOP and ON_ERROR_ROLLBACK for now.
	if ([@"set" isEqualToString: command])
	{
		if ([@"ON_ERROR_STOP" isEqualToString: options])
			[self setIgnoresErrors: NO];
		else if ([@"ON_ERROR_ROLLBACK" isEqualToString: options])
			[self setIgnoresErrors: YES];
	}
	else if ([@"unset" isEqualToString: command])
	{
		if ([@"ON_ERROR_STOP" isEqualToString: options])
			[self setIgnoresErrors: YES];
		else if ([@"ON_ERROR_ROLLBACK" isEqualToString: options])
			[self setIgnoresErrors: NO];
	}
	[mScanner continueScanning];
}
@end
