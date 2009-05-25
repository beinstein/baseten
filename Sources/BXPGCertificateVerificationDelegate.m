//
// BXPGCertificateVerificationDelegate.m
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

#import "BXPGCertificateVerificationDelegate.h"
#import "BXDatabaseContextPrivate.h"
#import "BXSafetyMacros.h"
#import "BXLogger.h"
#import <openssl/x509.h>


static BOOL
CertArrayCompare (CFArrayRef a1, CFArrayRef a2)
{
	BOOL retval = NO;
	CFIndex count = CFArrayGetCount (a1);
	if (CFArrayGetCount (a2) == count)
	{
		CSSM_DATA d1 = {};
		CSSM_DATA d2 = {};
		
		for (CFIndex i = 0; i < count; i++)
		{
			SecCertificateRef c1 = (SecCertificateRef) CFArrayGetValueAtIndex (a1, i);
			SecCertificateRef c2 = (SecCertificateRef) CFArrayGetValueAtIndex (a2, i);
			
			if (noErr != SecCertificateGetData (c1, &d1)) goto end;
			if (noErr != SecCertificateGetData (c2, &d2)) goto end;
			
			if (d1.Length != d2.Length) goto end;
			
			if (0 != memcmp (d1.Data, d2.Data, d1.Length)) goto end;
		}
		
		retval = YES;
	}
end:
	return retval;
}


@implementation BXPGCertificateVerificationDelegate
- (void) dealloc
{
	SafeCFRelease (mCertificates);
	[super dealloc];
}


- (void) finalize
{
	SafeCFRelease (mCertificates);
	[super finalize];
}


- (void) setHandler: (id <BXPGTrustHandler>) anObject
{
	mHandler = anObject;
}


- (void) setCertificates: (CFArrayRef) anArray
{
	if (mCertificates != anArray)
	{
		if (mCertificates)
			CFRelease (mCertificates);
		
		if (anArray)
			mCertificates = CFRetain (anArray);
	}
}


- (BOOL) PGTSAllowSSLForConnection: (PGTSConnection *) connection context: (void *) x509_ctx_ptr preverifyStatus: (int) preverifyStatus
{
	BOOL retval = NO;
	CFArrayRef certificates = [self copyCertificateArrayFromOpenSSLCertificates: (X509_STORE_CTX *) x509_ctx_ptr];
	
	//If we already have a certificate chain, the received chain has to match it.
	//Otherwise, create a trust and evaluate it.
	if (mCertificates)
	{
		if (CertArrayCompare (certificates, mCertificates))
			retval = YES;
		else
		{
			//FIXME: create an error indicating that the certificates have changed.
			BXLogError (@"Certificates seem to have changed between connection attempts?");
			retval = NO;
		}
	}
	else
	{
		[self setCertificates: certificates];
		
		SecTrustResultType result = kSecTrustResultInvalid;
		SecTrustRef trust = [self copyTrustFromCertificates: certificates];
		OSStatus status = SecTrustEvaluate (trust, &result);

		if (noErr != status)
			retval = NO;
		else if (kSecTrustResultProceed == result)
			retval = YES;
		else
			retval = [mHandler handleInvalidTrust: trust result: result];
		
		SafeCFRelease (trust);
	}
	
	SafeCFRelease (certificates);	
	return retval;
}

@end
