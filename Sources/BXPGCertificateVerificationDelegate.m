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
#import "BXDatabaseAdditions.h"
#import <openssl/x509.h>


@implementation BXPGCertificateVerificationDelegate

- (void) dealloc
{
	//[self clearCaches];
	[super dealloc];
}

#if 0
- (void) clearCaches
{
	if (NULL != mOpenSSLCertificates)
	{
		X509** chain = mOpenSSLCertificates;
		while (*(chain++))
			free (*chain);
		free (mOpenSSLCertificates);
		mOpenSSLCertificates = NULL;
	}
	[mConnectionString release];	
	mConnectionString = nil;
}

- (BOOL) PGTSAllowSSLForConnection: (PGTSConnection *) connection context: (void *) x509_ctx_ptr preverifyStatus: (int) preverifyStatus
{
	BOOL rval = NO;
	X509_STORE_CTX* x509_ctx = (X509_STORE_CTX *) x509_ctx_ptr;
	
	if (connection == mNotifyConnection || NULL != mOpenSSLCertificates || nil != mConnectionString)
	{
		if ([[connection connectionString] isEqualToString: mConnectionString] &&
			0 == X509_cmp (*mOpenSSLCertificates, x509_ctx->cert))
		{
			//If we have cached values, it means that the context has sent connectAsyncIfNeeded again and wants us to accept the certificate.
			//Validation for notifyConnection has to succeed on the first try.
			BOOL ok = YES;
			X509** chain = mOpenSSLCertificates;
			int i = 0, count = M_sk_num (x509_ctx->untrusted);
			while (i < count)
			{
				chain++;
				if (NULL == chain)
				{
					ok = NO;
					break;
				}
				
				ok = (0 == X509_cmp (*chain, (X509 *) M_sk_value (x509_ctx->untrusted, i)));
				if (!ok)
					break;
				i++;
			}
			
			if (ok && i == count && NULL == *(++chain))
			{
				//The certificates match; proceed with the connection.
				rval = YES;
			}
		}	
	}
	else
	{
		//First time through or synchronous.
		SecTrustResultType result = kSecTrustResultInvalid;
		SecTrustRef trust = [self copyTrustFromOpenSSLCertificates: x509_ctx];
		OSStatus status = SecTrustEvaluate (trust, &result);
		
		if (noErr == status && kSecTrustResultProceed == result)
			rval = YES;
		else if (NULL == mOpenSSLCertificates && nil == mConnectionString)
		{
			//Cache some connection info; the certificates go in a vector.
			//This needs to be done anyway for notifyConnection.
			mConnectionString = [[connection connectionString] copy];
			
			mOpenSSLCertificates = calloc (2 + (NULL == x509_ctx->untrusted ? 0 : sk_num (x509_ctx->untrusted)), sizeof (X509*));
			X509** chain = mOpenSSLCertificates;
			*chain = X509_dup (x509_ctx->cert);
			for (int i = 0, count = M_sk_num (x509_ctx->untrusted); i < count; i++)
			{
				chain++;
				*chain = X509_dup ((X509 *) M_sk_value (x509_ctx->untrusted, i));
			}
			
			if (NO == [connection connectingAsync])
			{
				rval = [mContext handleInvalidTrust: trust result: result];
				[mInterface setHasInvalidCertificate: !rval];
			}
			else
			{				
				//FIXME: This looks like a potential timing problem. Are we releasing trust before it has been passed to main thread?
				struct trustResult trustResult = {trust, result};
				CFRetain (trust);
				NSValue* resultValue = [NSValue valueWithBytes: &trustResult objCType: @encode (struct trustResult)];				
				[mContext performSelectorOnMainThread: @selector (handleInvalidTrustAsync:) withObject: resultValue waitUntilDone: NO];
			}
		}

		BXSafeCFRelease (trust);
	}
	
	return rval;
}
#endif

@end
