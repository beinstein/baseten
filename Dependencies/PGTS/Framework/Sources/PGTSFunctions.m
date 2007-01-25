//
// PGTSFunctions.m
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

#import <libgen.h>
#import <Foundation/Foundation.h>
#import <openssl/x509.h>
#import <openssl/ssl.h>
#import <Security/Security.h>
#import "postgresql/libpq-fe.h"
#import "PGTSFunctions.h"
#import "PGTSConstants.h"
#import "PGTSConnectionDelegate.h"
#import "PGTSConnectionPrivate.h"


void 
PGTSInit ()
{   
    static int tooLate = 0;
    if (0 == tooLate)
    {
        tooLate = 1;
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        
        kPGTSSentQuerySelector                  = @selector (PGTSConnection:sentQuery:);
        kPGTSFailedToSendQuerySelector          = @selector (PGTSConnection:failedToSendQuery:);
        kPGTSAcceptCopyingDataSelector          = @selector (PGTSConnection:acceptCopyingData:errorMessage:);
        kPGTSReceivedDataSelector               = @selector (PGTSConnection:receivedData:);
        kPGTSReceivedResultSetSelector          = @selector (PGTSConnection:receivedResultSet:);
        kPGTSReceivedErrorSelector              = @selector (PGTSConnection:receivedError:);
        kPGTSReceivedNoticeSelector             = @selector (PGTSConnection:receivedNotice:);
        
        kPGTSConnectionFailedSelector           = @selector (PGTSConnectionFailed:);
        kPGTSConnectionEstablishedSelector      = @selector (PGTSConnectionEstablished:);
        kPGTSStartedReconnectingSelector        = @selector (PGTSConnectionStartedReconnecting:);
        kPGTSDidReconnectSelector               = @selector (PGTSConnectionDidReconnect:);
        
        {
            NSMutableArray* keys = [NSMutableArray array];
            kPGTSDefaultConnectionDictionary = [[NSMutableDictionary alloc] init];
            
            PQconninfoOption *option = PQconndefaults ();
            char* keyword = NULL;
            while ((keyword = option->keyword))
            {
                NSString* key = [NSString stringWithUTF8String: keyword];
                [keys addObject: key];
                char* value = option->val;
                if (NULL == value)
                    value = getenv ([key UTF8String]);
                if (NULL == value)
                    value = option->compiled;
                if (NULL != value)
                {
                    [(NSMutableDictionary *) kPGTSDefaultConnectionDictionary setObject: 
                                      [NSString stringWithUTF8String: value] forKey: key];
                }
                option++;
            }
            kPGTSConnectionDictionaryKeys = [keys copy];
			
			//sslmode is disable by default??
			[(NSMutableDictionary *) kPGTSDefaultConnectionDictionary setObject: @"prefer" forKey: @"sslmode"];
        }
        [pool release];
    }
}

void 
PGTSNoticeProcessor (void* connection, const char* message)
{
    if (NULL != message)
    {
        [(PGTSConnection *) connection performSelectorOnMainThread: @selector (handleNotice:) 
                                                        withObject: [NSString stringWithUTF8String: message] 
                                                     waitUntilDone: NO];
    }
}

/**
 * Return the value as an object
 * \sa PGTSOidValue
 */
id 
PGTSOidAsObject (Oid o)
{
    //Methods inherited from NSValue seem to return an NSValue instead of an NSNumber
    return [NSNumber numberWithUnsignedInt: o];
}


NSString* 
PGTSModificationName (unichar type)
{
    NSString* modificationName = nil;
    switch (type)
    {
        case 'I':
            modificationName = kPGTSInsertModification;
            break;
        case 'U':
            modificationName = kPGTSUpdateModification;
            break;
        case 'D':
            modificationName = kPGTSDeleteModification;
            break;
        default:
            break;
    }
    return modificationName;
}


NSString*
PGTSLockOperation (unichar type)
{
    NSString* lockOperation = nil;
    switch (type)
    {
        case 'U':
            lockOperation = kPGTSLockedForUpdate;
            break;
        case 'D':
            lockOperation = kPGTSLockedForDelete;
            break;
        default:
            break;
    }
    return lockOperation;
}


inline CSSM_CERT_TYPE
x509Version (X509* x509Cert)
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

inline SecCertificateRef
SecCertificateFromX509 (X509* opensslCert, BIO* bioOutput)
{
	SecCertificateRef cert = NULL;
	if (i2d_X509_bio (bioOutput, opensslCert))
	{
		BUF_MEM* bioBuffer = NULL;
		BIO_get_mem_ptr (bioOutput, &bioBuffer);
		
		OSStatus status = SecCertificateCreateFromData ((void *) bioBuffer->data, x509Version (opensslCert), CSSM_CERT_ENCODING_DER, &cert);
		status = noErr;
	}
	return cert;
}

/**
 * \internal
 * Verify an X.509 certificate.
 * Get the X.509 certificate from OpenSSL, encode it in DER format and let Security framework parse it again.
 * This way, we can use the Keychain to verify the certificate, since a CA trusted by the OS or the user
 * might have signed it or the user could have stored the certificate earlier. The preverification result
 * is ignored because it rejects certificates from CAs unknown to OpenSSL. 
 */
int
PGTSVerifySSLSertificate (int preverify_ok, void* x509_ctx)
{
	return preverify_ok;
#if 0 
	int rval = 0;
	SSL* ssl = X509_STORE_CTX_get_ex_data ((X509_STORE_CTX *) x509_ctx, SSL_get_ex_data_X509_STORE_CTX_idx ());
	PGTSConnection* connection = SSL_get_ex_data (ssl, PGTSSSLConnectionExIndex ());
	
	//FIXME: move these into the delegate object and make the API such that X509 structure can also be used
	//when verifying.
	BIO* bioOutput = BIO_new (BIO_s_mem ());
	
	int count = M_sk_num (x509_ctx->untrusted);
	NSMutableArray* certs = [NSMutableArray arrayWithCapacity: count + 1];
	SecCertificateRef serverCert = CertificateFromX509 (x509_ctx->cert, bioOutput);
	[certs addObject: serverCert];
	
	for (int i = 0; i < count; i++)
	{
		BIO_reset (bioOutput);
		SecCertificateRef chainCert = CertificateFromX509 (M_sk_value (x509_ctx->untrusted, i));
		[certs addObject: chainCert];
	}
	
	SecTrustRef trust = NULL;
	OSStatus status = SecTrustCreateWithCertificates (certs,<#CFTypeRef policies#>, &trust);

	BIO_free (bioOutput);
	return rval;
#endif
}
