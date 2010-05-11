//
// PGTSConnector.m
// BaseTen
//
// Copyright (C) 2008-2010 Marko Karppinen & Co. LLC.
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


#import "PGTSConnector.h"
#import "PGTSConstants.h"
#import "PGTSConnection.h"
#import "BXLogger.h"
#import "BXError.h"
#import "NSString+PGTSAdditions.h"
#import "libpq_additions.h"


char*
PGTSCopyConnectionString (NSDictionary* connectionDict)
{
	NSMutableString* connectionString = [NSMutableString string];
	NSEnumerator* e = [connectionDict keyEnumerator];
	NSString* currentKey;
	NSString* format = @"%@ = '%@' ";
	while ((currentKey = [e nextObject]))
	{
		if ([kPGTSConnectionDictionaryKeys containsObject: currentKey])
			[connectionString appendFormat: format, currentKey, [connectionDict objectForKey: currentKey]];
	}
	char* retval = strdup ([connectionString UTF8String]);

	//For GC.
	[connectionString self];
	return retval;
}


#ifdef USE_SSL
#import "BXOpenSSLCompatibility.h"
//This is thread safe because it's called in +initialize for the first time.
//Afterwards, the static variable is only read.
static int
SSLConnectionExIndex ()
{
	static int sslConnectionExIndex = -1;
	if (-1 == sslConnectionExIndex)
		sslConnectionExIndex = SSL_get_ex_new_index (0, NULL, NULL, NULL, NULL);
	return sslConnectionExIndex;
}


/**
 * \internal
 * \brief Verify an X.509 certificate.
 */
static int
VerifySSLCertificate (int preverify_ok, X509_STORE_CTX *x509_ctx)
{
	int retval = 0;
	SSL* ssl = X509_STORE_CTX_get_ex_data (x509_ctx, SSL_get_ex_data_X509_STORE_CTX_idx ());
	PGTSConnector* connector = SSL_get_ex_data (ssl, SSLConnectionExIndex ());
	id <PGTSConnectorDelegate> delegate = [connector delegate];

	if ([delegate allowSSLForConnector: connector context: x509_ctx preverifyStatus: preverify_ok])
		retval = 1;
	else 
	{
		retval = 0;
		[connector setServerCertificateVerificationFailed: YES];
	}
	return retval;
}
#endif


@implementation PGTSConnector
+ (void) initialize
{
	static BOOL tooLate = NO;
	if (! tooLate)
	{
		tooLate = YES;
#ifdef USE_SSL
		SSLConnectionExIndex ();
#endif
	}
}

- (id) init
{
    if ((self = [super init]))
    {
        mPollFunction = &PQconnectPoll;
    }
    return self;
}

- (void) dealloc
{
	//Everything is weak.
	[super dealloc];
}

- (BOOL) SSLSetUp
{
	return mSSLSetUp;
}

- (id <PGTSConnectorDelegate>) delegate
{
	return mDelegate;
}

- (void) setDelegate: (id <PGTSConnectorDelegate>) anObject
{
	mDelegate = anObject;
}

- (BOOL) connect: (NSDictionary *) connectionDictionary
{
	return NO;
}

- (void) cancel
{
}

- (BOOL) start: (const char *) connectionString
{
	if (mConnection)
		PQfinish (mConnection);
	
	mConnection = PQconnectStart (connectionString);
	return (mConnection ? YES : NO);
}

- (void) setConnection: (PGconn *) connection
{
	mConnection = connection;
}

- (void) setTraceFile: (FILE *) stream
{
	mTraceFile = stream;
}

- (void) setServerCertificateVerificationFailed: (BOOL) aBool
{
	mServerCertificateVerificationFailed = aBool;
}

- (NSError *) connectionError
{
	return [[mConnectionError copy] autorelease];
}

- (void) setConnectionError: (NSError *) anError
{
	if (anError != mConnectionError)
	{
		[mConnectionError release];
		mConnectionError = [anError retain];
	}
}

- (void) finishedConnecting: (BOOL) status
{
	BXLogDebug (@"Finished connecting (%d).", status);
	
	if (status)
	{
		//Resign ownership. mConnection needs to be set to NULL before calling delegate method.
		PGconn* connection = mConnection;
		mConnection = NULL;
		[mDelegate connector: self gotConnection: connection];
	}
	else
	{
		if (! mConnectionError)
		{
			enum PGTSConnectionError code = kPGTSConnectionErrorNone;
			const char* SSLMode = pq_ssl_mode (mConnection);
			
			if (! mNegotiationStarted)
				code = kPGTSConnectionErrorUnknown;
			else if (0 == strcmp ("require", SSLMode))
			{
				if (mServerCertificateVerificationFailed)
					code = kPGTSConnectionErrorSSLCertificateVerificationFailed;
				else if (mSSLSetUp)
					code = kPGTSConnectionErrorSSLError;
				else
					code = kPGTSConnectionErrorSSLUnavailable;
			}
			else if (PQconnectionNeedsPassword (mConnection))
				code = kPGTSConnectionErrorPasswordRequired;
			else if (PQconnectionUsedPassword (mConnection))
				code = kPGTSConnectionErrorInvalidPassword;
			else
				code = kPGTSConnectionErrorUnknown;
			
			NSString* errorTitle = NSLocalizedStringWithDefaultValue (@"connectionError", nil, [NSBundle bundleForClass: [self class]],
																	  @"Connection error", @"Title for a sheet.");
			NSString* message = [NSString stringWithUTF8String: PQerrorMessage (mConnection)];
			message = PGTSReformatErrorMessage (message);
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  errorTitle, NSLocalizedDescriptionKey,
									  errorTitle, NSLocalizedFailureReasonErrorKey,
									  message, NSLocalizedRecoverySuggestionErrorKey,
									  nil];
			
			//FIXME: error code
			NSError* error = [BXError errorWithDomain: kPGTSConnectionErrorDomain code: code userInfo: userInfo];
			[self setConnectionError: error];
		}	
		
		PQfinish (mConnection);		
		mConnection = NULL;
		[mDelegate connectorFailed: self];		
	}	
}

- (void) setUpSSL
{
#ifdef USE_SSL
	ConnStatusType status = PQstatus (mConnection);
	if (! mSSLSetUp && CONNECTION_SSL_CONTINUE == status)
	{
		mSSLSetUp = YES;
		SSL* ssl = PQgetssl (mConnection);
		BXAssertVoidReturn (ssl, @"Expected ssl struct not to be NULL.");
		SSL_set_verify (ssl, SSL_VERIFY_PEER, &VerifySSLCertificate);
		SSL_set_ex_data (ssl, SSLConnectionExIndex (), self);
	}
#endif	
}

- (void) prepareForConnect
{
	mSSLSetUp = NO;
	mNegotiationStarted = NO;
	mServerCertificateVerificationFailed = NO;
	[self setConnectionError: nil];
}
@end
