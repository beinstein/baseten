//
// BXDatabaseContextDelegateDefaultImplementation.m
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

#import <AppKit/AppKit.h>
#import "BXDatabaseContext.h"
#import "BXDatabaseContextDelegateDefaultImplementation.h"
#import "BXException.h"
#import "BXDatabaseAdditions.h"
#import "BXLogger.h"


@implementation BXDatabaseContextDelegateDefaultImplementation
- (void) databaseContext: (BXDatabaseContext *) context 
				hadError: (NSError *) error 
		  willBePassedOn: (BOOL) willBePassedOn
{
	if (! willBePassedOn)
		@throw [error BXExceptionWithName: kBXExceptionUnhandledError];
}

- (void) databaseContext: (BXDatabaseContext *) context
	hadReconnectionError: (NSError *) error
{
	if (NULL != NSApp)
		[NSApp presentError: error];
	else
		BXLogError (@"Error while trying to reconnect: %@ (userInfo: %@).", error, [error userInfo]);
}

- (void) databaseContext: (BXDatabaseContext *) context lostConnection: (NSError *) error
{
	if (NULL != NSApp)
	{
		//FIXME: do something about this; not just logging.
		if ([NSApp presentError: error])
			BXLogInfo (@"Reconnected.");
		else
		{
			BXLogInfo (@"Failed to reconnect.");
			[context setAllowReconnecting: NO];
		}
	}
	else
	{
		@throw [error BXExceptionWithName: kBXExceptionUnhandledError];
	}
}

- (enum BXCertificatePolicy) databaseContext: (BXDatabaseContext *) ctx 
						  handleInvalidTrust: (SecTrustRef) trust 
									  result: (SecTrustResultType) result
{
	enum BXCertificatePolicy policy = kBXCertificatePolicyDeny;
	if (NULL != NSApp)
		policy = kBXCertificatePolicyDisplayTrustPanel;
	return policy;
}

- (enum BXSSLMode) SSLModeForDatabaseContext: (BXDatabaseContext *) ctx
{
	return kBXSSLModePrefer;
}
@end
