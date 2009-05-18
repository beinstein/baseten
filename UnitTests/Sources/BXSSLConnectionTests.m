//
// BXSSLConnectionTests.m
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

#import "BXSSLConnectionTests.h"
#import "MKCSenTestCaseAdditions.h"


@implementation BXSSLConnectionTests
- (void) setUp
{
	[super setUp];
	
	mSSLMode = kBXSSLModeUndefined;
	mCertificatePolicy = kBXCertificatePolicyUndefined;
	
    mContext = [[BXDatabaseContext alloc] init];
	[mContext setAutocommits: NO];
	[mContext setDelegate: self];
	[mContext setDatabaseURI: [self databaseURI]];
}


- (void) tearDown
{
	STAssertFalse (kBXSSLModeUndefined == mSSLMode, @"SSL mode should've been set in the test.");
	STAssertFalse (kBXCertificatePolicyUndefined == mCertificatePolicy, @"Certificate policy should've been set in the test.");
	[mContext disconnect];
    [mContext release];
	[super tearDown];
}


- (enum BXSSLMode) SSLModeForDatabaseContext: (BXDatabaseContext *) ctx
{
	return mSSLMode;
}


- (enum BXCertificatePolicy) databaseContext: (BXDatabaseContext *) ctx 
						  handleInvalidTrust: (SecTrustRef) trust 
									  result: (SecTrustResultType) result
{
	return mCertificatePolicy;
}


- (void) testRequireSSLWithAllow
{
	mSSLMode = kBXSSLModeRequire;
	mCertificatePolicy = kBXCertificatePolicyAllow;
	
	NSError* error = nil;
	BOOL status = [mContext connectSync: &error];
	STAssertTrue (status, [error description]);
	MKCAssertTrue ([mContext isSSLInUse]);
}


- (void) testPreferSSLWithAllow
{
	mSSLMode = kBXSSLModePrefer;
	mCertificatePolicy = kBXCertificatePolicyAllow;

	NSError* error = nil;
	BOOL status = [mContext connectSync: &error];
	STAssertTrue (status, [error description]);
	MKCAssertTrue ([mContext isSSLInUse]);	
}


- (void) testRequireSSLWithDeny
{
	mSSLMode = kBXSSLModeRequire;
	mCertificatePolicy = kBXCertificatePolicyDeny;
	
	NSError* error = nil;
	BOOL status = [mContext connectSync: &error];
	MKCAssertFalse (status);
	MKCAssertNotNil (error);
	MKCAssertTrue ([kBXErrorDomain isEqualToString: [error domain]]);
	MKCAssertTrue (kBXErrorSSLCertificateVerificationFailed == [error code]);
}


- (void) testPreferSSLWithDeny
{
	mSSLMode = kBXSSLModePrefer;
	mCertificatePolicy = kBXCertificatePolicyDeny;
	
	NSError* error = nil;
	BOOL status = [mContext connectSync: &error];
	MKCAssertFalse (status);
	MKCAssertNotNil (error);
	MKCAssertTrue ([kBXErrorDomain isEqualToString: [error domain]]);
	MKCAssertTrue (kBXErrorSSLCertificateVerificationFailed == [error code]);	
}
@end
