//
// PGTSSertificateVerificationDelegate.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
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
// $Id: PGTSFunctions.m 101 2007-01-23 16:25:46Z tuukka.norri@karppinen.fi $
//

#import "PGTSSertificateVerificationDelegate.h"
#import <Security/Security.h>


@implementation PGTSSertificateVerificationDelegate

- (id) init
{
	return nil;
}

- (void) dealloc
{
	[mPolicies release];
	[super dealloc];
}

/*
 * To verify a certificate, we need to
 * create a trust. To create a trust, we need to find search policies. To find search policies, we need to create
 * a search criteria. To create a search criteria, we need to give the criteria creation function some constants.
 */
- (NSArray *) policies
{
	if (nil == mPolicies)
	{
		//FIXME: this doesn't compile :(
#if 0
		OSStatus status = noErr;
	
		mPolicies = [[NSMutableArray alloc] init];
		int i = 0;
		CSSM_OID currentOid;
		CSSM_OID* oids = {CSSMOID_APPLE_TP_SSL, CSSMOID_APPLE_TP_REVOCATION_CRL, NULL};
		while (NULL != (currentOid = oids [i]))
		{
			SecPolicySearchRef criteria = NULL;
			SecPolicyRef policy = NULL;
			status = SecPolicySearchCreate (CSSM_CERT_X_509v3, currentOid, NULL, &criteria);
			while (noErr == SecPolicySearchCopyNext (criteria, &policy))
			{
				[policies addObject: policy];
				CFRelease (policy);
			}
			CFRelease (criteria);
		}
#endif
	}
	return mPolicies;
}

@end
