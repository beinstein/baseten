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

#import "PGTS.h"
#import "BXPGSQLScanner.h"
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

- (void) openFileAtURL: (NSURL *) fileURL
{
	if (! mFile)
	{
		const char* path = [[fileURL path] UTF8String];
		mFile = fopen (path, "r");
	}
}
   
- (void) readAndExecuteAsynchronously
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

- (void) receivedResult: (PGTSResultSet *) res
{
	if ([res querySucceeded])
		[mScanner continueScanning];
}

- (void) scriptEnded
{
	if (mFile)
		fclose (mFile);
}

- (void) dealloc
{
	if (mFile)
		fclose (mFile);
	[mScanner release];
	[mConnection release];
	[super dealloc];
}

- (void) finalize
{
	if (mFile)
		fclose (mFile);
	[super finalize];
}
@end


@implementation BXPGSQLScriptReader (BXPGSQLScannerDelegate)
- (const char *) nextLineForScanner: (BXPGSQLScanner *) scanner
{
	const char* retval = fgets (mBuffer, BXPGSQLScannerBufferSize, mFile);
	if (! retval)
		[self scriptEnded];
	return retval;
}

- (void) scanner: (BXPGSQLScanner *) scanner scannedQuery: (NSString *) query complete: (BOOL) isComplete
{
	if (isComplete)
		[mConnection sendQuery: query delegate: self callback: @selector (receivedResult:)];
}

- (void) scanner: (BXPGSQLScanner *) scanner scannedCommand: (NSString *) command options: (NSString *) options
{
	[mScanner continueScanning];
}
@end
