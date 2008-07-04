//
// BXPGSQLScanner.m
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

#import <stdint.h>

typedef uint64_t uint64;

#import "settings.h"
#import "pgsqlscan.h"

PsqlSettings pset = {};

void UnsyncVariables ()
{
	//Do nothing.
}


#import "BXPGSQLScanner.h"


@implementation BXPGSQLScanner

- (id) init
{
	if ((self = [super init]))
	{
		mQueryBuffer = createPQExpBuffer ()
		mScanState = psql_scan_create ();
		mShouldStartScanning = YES;
	}
	return self;
}

- (void) dealloc
{
	destroyPQExpBuffer (mQueryBuffer);
	psql_scan_destroy (mScanState);
	[super dealloc];
}

- (void) finalize
{
	destroyPQExpBuffer (mQueryBuffer);
	psql_scan_destroy (mScanState);
	[super finalize];
}

- (void) continueScanning
{
	if (! mCurrentLine)
		mCurrentLine = [mDelegate nextLineForScanner: self];
		
	if (mCurrentLine)
	{
		if (mShouldStartScanning)
		{
			psql_scan_setup (mScanState, mCurrentLine, strlen (mCurrentLine));
			mShouldStartScanning = NO;
		}
		
		promptStatus_t promptStatus = PROMPT_READY; //Quite the same what we have here; it's write-only.
		PsqlScanResult scanResult = psql_scan (mScanState, mQueryBuffer, &promptStatus);
		
		switch (scanResult)
		{
			/* found command-ending semicolon */
			case PSCAN_SEMICOLON:
#error make me work
				break;
			
			/* end of line, SQL possibly complete */
			case PSCAN_EOL:
				psql_scan_finish (mScanState);
#error make me work
				break;				
		
			/* end of line, SQL statement incomplete */
			case PSCAN_INCOMPLETE:
			{
				psql_scan_finish (mScanState);
				mCurrentLine = NULL;
				const char* nextLine = [mDelegate nextLineForScanner: self];
				if (nextLine)
				{
					mCurrentLine = nextLine;
					[self continueScanning];
					//Tail recursion.
				}
				else
				{
#error make the query.
					psql_scan_finish (mScanState);
					mCurrentLine = NULL;
					[mDelegate scanner: self scannedQuery: nil complete: NO];
				}				
				break;
			}				
				
			/* found backslash command */
			case PSCAN_BACKSLASH:
			{
				NSString* commandString = nil;
				NSString* optionsString = nil;
				
				char* command = psql_scan_slash_command (mScanState);
				commandString = [[NSString alloc] initWithBytesNoCopy: &command length: strlen (command)
															 encoding: NSUTF8StringEncoding freeWhenDone: YES];
				[commandString autorelease];
				
				char* options = psql_scan_slash_option (mScanState, OT_WHOLE_LINE, NULL, true);
				if (options)
				{
					optionsString = [[NSString alloc] initWithBytesNoCopy: &options length: strlen (options)
																 encoding: NSUTF8StringEncoding freeWhenDone: YES];
					[optionsString autorelease];
				}
				
				[mDelegate scanner: self scannedCommand: commandString options: optionsString];
				psql_scan_slash_command_end (mScanState);
				psql_scan_finish (mScanState);
				mCurrentLine = NULL;
				mShouldStartScanning = YES;
				break;
			}
		}
	}
}

@end
