//
// PGTSNotificationTests.m
// BaseTen
//
// Copyright (C) 2009 Marko Karppinen & Co. LLC.
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

#import "PGTSNotificationTests.h"
#import "MKCSenTestCaseAdditions.h"


@implementation PGTSNotificationTests
- (void) PGTSConnectionFailed: (PGTSConnection *) connection
{
}

- (void) PGTSConnectionEstablished: (PGTSConnection *) connection
{
}

- (void) PGTSConnectionLost: (PGTSConnection *) connection error: (NSError *) error
{
}

- (void) PGTSConnection: (PGTSConnection *) connection gotNotification: (PGTSNotification *) notification
{
	mGotNotification = YES;
}

- (void) PGTSConnection: (PGTSConnection *) connection receivedNotice: (NSError *) notice
{
}

- (FILE *) PGTSConnectionTraceFile: (PGTSConnection *) connection
{
	return NULL;
}

- (void) PGTSConnection: (PGTSConnection *) connection networkStatusChanged: (SCNetworkConnectionFlags) newFlags
{
}

- (void) setUp
{
	NSString* connectionString = @"host = 'localhost' user = 'baseten_test_user' dbname = 'basetentest'";
	mConnection = [[PGTSConnection alloc] init];
	BOOL status = [mConnection connectSync: connectionString];
	STAssertTrue (status, [[mConnection connectionError] description]);
	
	[mConnection setDelegate: self];
}	

- (void) tearDown
{
	[mConnection disconnect];
	[mConnection release];
}

- (void) testNotification
{
	PGTSResultSet* res = nil;
	res = [mConnection executeQuery: @"LISTEN test_notification"];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	
	res = [mConnection executeQuery: @"NOTIFY test_notification"];
	STAssertTrue ([res querySucceeded], [[res error] description]);

	MKCAssertTrue (mGotNotification);
}
@end
