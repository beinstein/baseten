//
// BXTestCase.m
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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

#import <SenTestingKit/SenTestingKit.h>
#import <BaseTen/BaseTen.h>
#import <BaseTen/PGTSConstants.h>
#import "BXTestCase.h"
#import "MKCSenTestCaseAdditions.h"


int d_eq (double a, double b)
{
	double aa = fabs (a);
	double bb = fabs (b);
	return (fabs (aa - bb) <= (FLT_EPSILON * MAX (aa, bb)));
}


@interface SenTestCase (UndocumentedMethods)
- (void) logException:(NSException *) anException;
@end


@implementation BXTestCase
static void
bx_test_failed (NSException* exception)
{
	abort ();
}

- (void) logAndCallBXTestFailed: (NSException *) exception
{
	[self logException: exception];
	bx_test_failed (exception);
}

- (id) initWithInvocation: (NSInvocation *) anInvocation
{
	if ((self = [super initWithInvocation: anInvocation]))
	{
		[self setFailureAction: @selector (logAndCallBXTestFailed:)];
	}
	return self;
}

- (NSURL *) databaseURI
{
	return [NSURL URLWithString: @"pgsql://baseten_test_user@localhost/basetentest"];
}

- (NSDictionary *) connectionDictionary
{
	NSDictionary* connectionDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
										  @"localhost", kPGTSHostKey,
										  @"baseten_test_user", kPGTSUserNameKey,
										  @"basetentest", kPGTSDatabaseNameKey,
										  @"disable", kPGTSSSLModeKey,
										  nil];
	return connectionDictionary;
}

- (enum BXSSLMode) SSLModeForDatabaseContext: (BXDatabaseContext *) ctx
{
	return kBXSSLModeDisable;
}
@end


@implementation BXDatabaseTestCase
- (void) setUp
{
	[super setUp];
	
	NSURL* databaseURI = [self databaseURI];

	mContext = [[BXDatabaseContext alloc] init];
	[mContext setDatabaseURI: databaseURI];
	[mContext setAutocommits: NO];
	[mContext setDelegate: self];
	
	MKCAssertFalse ([mContext autocommits]);
}

- (void) tearDown
{
	[mContext disconnect];
	[mContext release];
	[super tearDown];
}
@end
