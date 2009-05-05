//
// BXSQLTests.m
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

#import "BXSQLTests.h"
#import "MKCSenTestCaseAdditions.h"
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXPGInterface.h>
#import <BaseTen/BXPGTransactionHandler.h>
#import <BaseTen/PGTSConnection.h>
#import <BaseTen/PGTSResultSet.h>


@implementation BXSQLTests
- (NSURL *) databaseURI
{
	return [NSURL URLWithString: @"pgsql://baseten_test_owner@localhost/basetentest"];
}

- (BOOL) checkEnablingForTest: (PGTSConnection *) connection
{
	BOOL retval = NO;
	NSString* query = @"SELECT baseten.is_enabled (id) FROM baseten.relation WHERE nspname = 'public' AND relname = 'test'";
	PGTSResultSet* res = [connection executeQuery: query];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	[res advanceRow];
	retval = [[res valueForKey: @"is_enabled"] boolValue];
	return retval;
}

- (void) testDisableEnable
{
	NSError* error = nil;
	[mContext connectSync: &error];
	STAssertNil (error, [error localizedDescription]);
	
	BXPGTransactionHandler* handler = [(BXPGInterface *) [mContext databaseInterface] transactionHandler];
	PGTSConnection* connection = [handler connection];
	MKCAssertNotNil (handler);
	MKCAssertNotNil (connection);
	
	PGTSResultSet* res = nil;
	NSString* query = nil;
	
	res = [connection executeQuery: @"BEGIN"];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	
	MKCAssertTrue ([self checkEnablingForTest: connection]);
	
	query = 
	@"SELECT baseten.disable (c.oid) "
	@" FROM pg_class c "
	@" INNER JOIN pg_namespace n ON (n.oid = c.relnamespace) "
	@" WHERE n.nspname = 'public' AND c.relname = 'test'";
	res = [connection executeQuery: query];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	
	MKCAssertFalse ([self checkEnablingForTest: connection]);
	
	query = 
	@"SELECT baseten.enable (c.oid) "
	@" FROM pg_class c "
	@" INNER JOIN pg_namespace n ON (n.oid = c.relnamespace) "
	@" WHERE n.nspname = 'public' AND c.relname = 'test'";
	res = [connection executeQuery: query];
	STAssertTrue ([res querySucceeded], [[res error] description]);

	MKCAssertTrue ([self checkEnablingForTest: connection]);
	
	res = [connection executeQuery: @"ROLLBACK"];
	STAssertTrue ([res querySucceeded], [[res error] description]);
}

- (void) testPrune
{
	NSError* error = nil;
	[mContext connectSync: &error];
	STAssertNil (error, [error localizedDescription]);
	
	BXPGTransactionHandler* handler = [(BXPGInterface *) [mContext databaseInterface] transactionHandler];
	PGTSConnection* connection = [handler connection];
	MKCAssertNotNil (handler);
	MKCAssertNotNil (connection);
	
	NSString* query = nil;
	PGTSResultSet* res = nil;

	query = @"SELECT baseten.prune ()";
	res = [connection executeQuery: query];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	
	query = @"SELECT COUNT (baseten_modification_id) FROM baseten.modification";
	res = [connection executeQuery: query];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	[res advanceRow];
	MKCAssertTrue (0 == [[res valueForKey: @"count"] integerValue]);
	
	query = @"SELECT COUNT (baseten_lock_id) FROM baseten.lock";
	res = [connection executeQuery: query];
	STAssertTrue ([res querySucceeded], [[res error] description]);
	[res advanceRow];
	MKCAssertTrue (0 == [[res valueForKey: @"count"] integerValue]);	
}
@end
