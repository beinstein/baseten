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
// $Id$
//

#import "PGTSCertificateVerificationDelegate.h"
#import "BXSafetyMacros.h"
#import <Security/Security.h>
#import "BXOpenSSLCompatibility.h"
#import "BXArraySize.h"


__strong static id <PGTSCertificateVerificationDelegate> gDefaultCertDelegate = nil;

/**
 * \internal
 * \brief Default implementation for verifying OpenSSL X.509 certificates.
 *
 * This class is thread-safe.
 */
@implementation PGTSCertificateVerificationDelegate

+ (id) defaultCertificateVerificationDelegate
{
	if (! gDefaultCertDelegate)
	{
		@synchronized (self)
		{
			if (! gDefaultCertDelegate)
				gDefaultCertDelegate = [[self alloc] init];
		}
	}
	return gDefaultCertDelegate;
}

- (id) init
{
	if ((self = [super init]))
	{
	}
	return self;
}

- (void) dealloc
{
	SafeCFRelease (mPolicies);
	[super dealloc];
}

- (void) finalize
{
	SafeCFRelease (mPolicies);
	[super finalize];
}

- (CSSM_CERT_TYPE) x509Version: (X509 *) x509Cert
{
	CSSM_CERT_TYPE retval = CSSM_CERT_X_509v3;
	switch (X509_get_version (x509Cert))
	{
		case 1:
			retval = CSSM_CERT_X_509v1;
			break;
		case 2:
			retval = CSSM_CERT_X_509v2;
			break;
		case 3:
		default:
			break;
	}
	return retval;
}

/**
 * \brief Get search policies.
 *
 * To find search policies, we need to create a search criteria. To create a search criteria, 
 * we need to give the criteria creation function some constants.
 */
- (CFArrayRef) policies
{
	if (! mPolicies)
	{
		OSStatus status = noErr;
		
		CFMutableArrayRef policies = CFArrayCreateMutable (NULL, 0, &kCFTypeArrayCallBacks);
		const CSSM_OID* currentOidPtr = NULL;
		const CSSM_OID* oidPtrs [] = {&CSSMOID_APPLE_TP_SSL, &CSSMOID_APPLE_TP_REVOCATION_CRL};
		for (int i = 0, count = BXArraySize (oidPtrs); i < count; i++)
		{
			currentOidPtr = oidPtrs [i];
			SecPolicySearchRef criteria = NULL;
			SecPolicyRef policy = NULL;
			status = SecPolicySearchCreate (CSSM_CERT_X_509v3, currentOidPtr, NULL, &criteria);
			if (noErr != status)
			{
				SafeCFRelease (criteria);
				CFArrayRemoveAllValues (policies);
				break;
			}
			
			//SecPolicySearchCopyNext should only return noErr or errSecPolicyNotFound.
			while (noErr == SecPolicySearchCopyNext (criteria, &policy))
			{
				CFArrayAppendValue (policies, policy);
				CFRelease (policy);
			}
			SafeCFRelease (criteria);
		}
		
		if (noErr == status)
			mPolicies = CFArrayCreateCopy (NULL, policies);
		
		SafeCFRelease (policies);
		
	}
	return mPolicies;
}

/**
 * \brief Create a SecCertificateRef from an OpenSSL certificate.
 * \param bioOutput A memory buffer so we don't have to allocate one.
 */
- (SecCertificateRef) copyCertificateFromX509: (X509 *) opensslCert bioOutput: (BIO *) bioOutput
{
	SecCertificateRef cert = NULL;
	
	if (bioOutput && opensslCert)
	{
		BIO_reset (bioOutput);
		if (i2d_X509_bio (bioOutput, opensslCert))
		{
			BUF_MEM* bioBuffer = NULL;
			BIO_get_mem_ptr (bioOutput, &bioBuffer);
			CSSM_DATA* cssmCert = alloca (sizeof (CSSM_DATA));
			cssmCert->Data = (uint8 *) bioBuffer->data;
			cssmCert->Length = bioBuffer->length;
			
			OSStatus status = SecCertificateCreateFromData (cssmCert, [self x509Version: opensslCert], CSSM_CERT_ENCODING_DER, &cert);
			if (noErr != status)
			{
				SafeCFRelease (cert);
				cert = NULL;
			}
		}
	}
	return cert;
}

/**
 * \brief Verify an OpenSSL X.509 certificate.
 *
 * Get the X.509 certificate from OpenSSL, encode it in DER format and let Security framework parse it again.
 * This way, we can use the Keychain to verify the certificate, since a CA trusted by the OS or the user
 * might have signed it or the user could have stored the certificate earlier. The preverification result
 * is ignored because it rejects certificates from CAs unknown to OpenSSL. 
 */ 
- (BOOL) PGTSAllowSSLForConnection: (PGTSConnection *) connection context: (void *) x509_ctx preverifyStatus: (int) preverifyStatus
{
	BOOL retval = NO;
	SecTrustResultType result = kSecTrustResultInvalid;	
	CFArrayRef certificates = NULL;
	SecTrustRef trust = NULL;
	
	certificates = [self copyCertificateArrayFromOpenSSLCertificates: (X509_STORE_CTX *) x509_ctx];
	if (! certificates)
		goto error;
	
	trust = [self copyTrustFromCertificates: certificates];
	if (! trust)
		goto error;
	
	OSStatus status = SecTrustEvaluate (trust, &result);
	if (noErr == status && kSecTrustResultProceed == result)
		retval = YES;

error:
	SafeCFRelease (certificates);
	SafeCFRelease (trust);
	return retval;
}

/**
 * \brief Create a trust.
 *
 * To verify a certificate, we need to
 * create a trust. To create a trust, we need to find search policies.
 * \param certificates An array of SecCertificateRefs.
 */
- (SecTrustRef) copyTrustFromCertificates: (CFArrayRef) certificates
{
	SecTrustRef trust = NULL;
	CFArrayRef policies = [self policies];
	if (policies && 0 < CFArrayGetCount (policies))
	{
		OSStatus status = SecTrustCreateWithCertificates (certificates, policies, &trust);
		if (noErr != status)
		{
			SafeCFRelease (trust);
			trust = NULL;
		}
	}
	return trust;
}

/**
 * \brief Create Security certificates from OpenSSL certificates.
 * \return An array of SecCertificateRefs.
 */
- (CFArrayRef) copyCertificateArrayFromOpenSSLCertificates: (X509_STORE_CTX *) x509_ctx
{
	CFMutableArrayRef certs = NULL;
	BIO* bioOutput = BIO_new (BIO_s_mem ());
	
	if (bioOutput)
	{
		int count = M_sk_num (x509_ctx->untrusted);
		SecCertificateRef serverCert = [self copyCertificateFromX509: x509_ctx->cert bioOutput: bioOutput];
		if (serverCert)
		{
			certs = (CFArrayCreateMutable (NULL, count + 1, &kCFTypeArrayCallBacks));
			CFArrayAppendValue (certs, serverCert);
			SafeCFRelease (serverCert);
			
			for (int i = 0; i < count; i++)
			{
				SecCertificateRef chainCert = [self copyCertificateFromX509: (X509 *) M_sk_value (x509_ctx->untrusted, i)
																  bioOutput: bioOutput];
				if (chainCert)
				{
					CFArrayAppendValue (certs, chainCert);
					CFRelease (chainCert);
				}
				else
				{
					SafeCFRelease (certs);
					certs = NULL;
					break;
				}
			}
		}
		BIO_free (bioOutput);
	}
	
	CFArrayRef retval = NULL;
	if (certs)
	{
		retval = CFArrayCreateCopy (NULL, certs);
		CFRelease (certs);
	}
	return retval;
}
@end
