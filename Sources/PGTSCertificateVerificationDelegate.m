//
// PGTSCertificateVerificationDelegate.m
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

#import "PGTSCertificateVerificationDelegate.h"
#import "PGTSFunctions.h"
#import <Security/Security.h>
#import <openssl/ssl.h>


@implementation PGTSCertificateVerificationDelegate

- (id) init
{
	if ((self = [super init]))
	{
	}
	return self;
}

- (void) dealloc
{
	[mPolicies release];
	[super dealloc];
}

/**
 * Verify an OpenSSL X.509 certificate.
 * Get the X.509 certificate from OpenSSL, encode it in DER format and let Security framework parse it again.
 * This way, we can use the Keychain to verify the certificate, since a CA trusted by the OS or the user
 * might have signed it or the user could have stored the certificate earlier. The preverification result
 * is ignored because it rejects certificates from CAs unknown to OpenSSL. 
 */ 
- (BOOL) PGTSAllowSSLForConnection: (PGTSConnection *) connection context: (void *) x509_ctx preverifyStatus: (int) preverifyStatus
{
	BOOL rval = NO;
	SecTrustResultType result = kSecTrustResultInvalid;
	SecTrustRef trust = [self copyTrustFromOpenSSLCertificates: (X509_STORE_CTX *) x509_ctx];
	OSStatus status = SecTrustEvaluate (trust, &result);
	if (noErr == status && kSecTrustResultProceed == result)
		rval = YES;

	SafeCFRelease (trust);
	return rval;
}

- (CSSM_CERT_TYPE) x509Version: (X509 *) x509Cert
{
	CSSM_CERT_TYPE rval = CSSM_CERT_X_509v3;
	switch (X509_get_version (x509Cert))
	{
		case 1:
			rval = CSSM_CERT_X_509v1;
			break;
		case 2:
			rval = CSSM_CERT_X_509v2;
			break;
		case 3:
		default:
			break;
	}
	return rval;
}

/**
 * Create a trust.
 * To verify a certificate, we need to
 * create a trust. To create a trust, we need to find search policies.
 */
- (SecTrustRef) copyTrustFromOpenSSLCertificates: (X509_STORE_CTX *) x509_ctx
{
	BIO* bioOutput = BIO_new (BIO_s_mem ());
	
	int count = M_sk_num (x509_ctx->untrusted);
	NSMutableArray* certs = [NSMutableArray arrayWithCapacity: count + 1];
	SecCertificateRef serverCert = [self copyCertificateFromX509: x509_ctx->cert bioOutput: bioOutput];
	CFArrayAppendValue ((CFMutableArrayRef) certs, serverCert);
	SafeCFRelease (serverCert);
	
	for (int i = 0; i < count; i++)
	{
		SecCertificateRef chainCert = [self copyCertificateFromX509: (X509 *) M_sk_value (x509_ctx->untrusted, i)
														  bioOutput: bioOutput];
		CFArrayAppendValue ((CFMutableArrayRef) certs, chainCert);
		SafeCFRelease (chainCert);
	}
	
	SecTrustRef trust = NULL;
	OSStatus status = SecTrustCreateWithCertificates ((CFArrayRef) certs, [self policies], &trust);
	status = noErr;
	
	BIO_free (bioOutput);
	return trust;
}

- (SecCertificateRef) copyCertificateFromX509: (X509 *) opensslCert bioOutput: (BIO *) bioOutput
{
	SecCertificateRef cert = NULL;
	BIO_reset (bioOutput);
	if (i2d_X509_bio (bioOutput, opensslCert))
	{
		BUF_MEM* bioBuffer = NULL;
		BIO_get_mem_ptr (bioOutput, &bioBuffer);
		CSSM_DATA* cssmCert = alloca (sizeof (CSSM_DATA));
		cssmCert->Data = (uint8 *) bioBuffer->data;
		cssmCert->Length = bioBuffer->length;
		
		OSStatus status = SecCertificateCreateFromData (cssmCert, [self x509Version: opensslCert], CSSM_CERT_ENCODING_DER, &cert);
		status = noErr;
	}
	return cert;
}
	
/**
 * Get search policies.
 * To find search policies, we need to create
 * a search criteria. To create a search criteria, we need to give the criteria creation function some constants.
 */
- (NSArray *) policies
{
	if (nil == mPolicies)
	{
		OSStatus status = noErr;
	
		mPolicies = [[NSMutableArray alloc] init];
		int i = 0;
		const CSSM_OID* currentOidPtr = NULL;
		const CSSM_OID* oidPtrs [] = {&CSSMOID_APPLE_TP_SSL, &CSSMOID_APPLE_TP_REVOCATION_CRL, NULL};
		while (NULL != (currentOidPtr = oidPtrs [i]))
		{
			SecPolicySearchRef criteria = NULL;
			SecPolicyRef policy = NULL;
			status = SecPolicySearchCreate (CSSM_CERT_X_509v3, currentOidPtr, NULL, &criteria);
			while (noErr == SecPolicySearchCopyNext (criteria, &policy))
			{
				CFArrayAppendValue ((CFMutableArrayRef) mPolicies, policy);
				SafeCFRelease (policy);
			}
			SafeCFRelease (criteria);
			i++;
		}
	}
	return mPolicies;
}

@end
