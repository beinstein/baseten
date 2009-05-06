//
// PGTSConnector.m
// BaseTen
//
// Copyright (C) 2008 Marko Karppinen & Co. LLC.
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
#import "PGTSConnection.h"
#import "PGTSConstants.h"
#import "PGTSCertificateVerificationDelegateProtocol.h"
#import "BXLogger.h"
#import "BXError.h"
#import "NSString+PGTSAdditions.h"
#import "libpq_additions.h"
#import <sys/select.h>


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
	SSL* ssl = X509_STORE_CTX_get_ex_data (x509_ctx, SSL_get_ex_data_X509_STORE_CTX_idx ());
	PGTSConnection* connection = SSL_get_ex_data (ssl, SSLConnectionExIndex ());
	int retval = (YES == [[connection certificateVerificationDelegate] PGTSAllowSSLForConnection: connection context: x509_ctx preverifyStatus: preverify_ok]);
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

- (void) setDelegate: (id <PGTSConnectorDelegate>) anObject
{
	mDelegate = anObject;
}

- (BOOL) connect: (const char *) conninfo
{
	return NO;
}

- (void) cancel
{
}

- (BOOL) start: (const char *) connectionString
{
	BXAssertLog (! mConnection, @"Expected not to have mConnection set.");
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
	if (status)
	{
		//Resign ownership. mConnection needs to be set to NULL before calling delegate method.
		PGconn* connection = mConnection;
		mConnection = NULL;
		[mDelegate connector: self gotConnection: connection];
	}
	else
	{
		{
			enum PGTSConnectionError code = kPGTSConnectionErrorNone;
			const char* SSLMode = pq_ssl_mode (mConnection);
			
			if (! mNegotiationStarted)
				code = kPGTSConnectionErrorUnknown;
			else if (! mSSLSetUp && 0 == strcmp ("require", SSLMode))
				code = kPGTSConnectionErrorSSLUnavailable;
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
			
			NSError* error = [BXError errorWithDomain: kPGTSConnectionErrorDomain code: code userInfo: userInfo];
			[self setConnectionError: error];
		}	
		
		PQfinish (mConnection);		
		mConnection = NULL;
		[mDelegate connectorFailed: self];		
	}	
}
@end


@implementation PGTSAsynchronousConnector

static void 
SocketReady (CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void* data, void* self)
{
	[(id) self socketReady];
}

- (void) setCFRunLoop: (CFRunLoopRef) aRef
{
	if (mRunLoop != aRef)
	{
		if (mRunLoop) CFRelease (mRunLoop);
		if (aRef)
		{
			mRunLoop = aRef;
			CFRetain (mRunLoop);
		}
	}
}

- (void) freeCFTypes
{
	//Don't release the connection. Delegate will handle it.
	if (mSocketSource)
	{
		CFRunLoopSourceInvalidate (mSocketSource);
		CFRelease (mSocketSource);
		mSocketSource = NULL;
	}
	
	if (mSocket)
	{
		CFSocketInvalidate (mSocket);
		CFRelease (mSocket);
		mSocket = NULL;
	}
	
	if (mRunLoop)
	{
		CFRelease (mRunLoop);
		mRunLoop = NULL;
	}
}

- (void) cancel
{
    if (mConnection)
    {
        PQfinish (mConnection);
        mConnection = NULL;
    }
}

- (void) dealloc
{
	[self freeCFTypes];
	[self cancel];
	[mConnectionError release];
	[super dealloc];
}

- (void) finalize
{
	[self freeCFTypes];
	[self cancel];
	[super finalize];
}

- (void) socketReady
{
	PostgresPollingStatusType status = mPollFunction (mConnection);
	
#ifdef USE_SSL
	if (! mSSLSetUp && CONNECTION_SSL_CONTINUE == PQstatus (mConnection))
	{
		mSSLSetUp = YES;
		SSL* ssl = PQgetssl (mConnection);
		BXAssertVoidReturn (ssl, @"Expected ssl struct not to be NULL.");
		SSL_set_verify (ssl, SSL_VERIFY_PEER, &VerifySSLCertificate);
		SSL_set_ex_data (ssl, SSLConnectionExIndex (), mConnection);
	}
#endif
	
	switch (status)
	{
        case PGRES_POLLING_OK:
			[self finishedConnecting: YES];
			break;
			
        case PGRES_POLLING_FAILED:
			[self finishedConnecting: NO];
            break;
			
		case PGRES_POLLING_ACTIVE:
			[self socketReady];
			break;
            
        case PGRES_POLLING_READING:
			CFSocketEnableCallBacks (mSocket, kCFSocketReadCallBack);
            break;
            
        case PGRES_POLLING_WRITING:
        default:
			CFSocketEnableCallBacks (mSocket, kCFSocketWriteCallBack);
            break;
	}
}

- (void) finishedConnecting: (BOOL) succeeded
{
	[self freeCFTypes];
	[super finishedConnecting: succeeded];
}

- (BOOL) connect: (const char *) conninfo
{
	BOOL retval = NO;	
	mNegotiationStarted = NO;
	if ([self start: conninfo])
	{
		if (CONNECTION_BAD == PQstatus (mConnection))
			[self finishedConnecting: NO];
		else
		{
			mNegotiationStarted = YES;
			int bsdSocket = PQsocket (mConnection);
			if (0 <= bsdSocket)
			{
				if (mTraceFile)
					PQtrace (mConnection, mTraceFile);
				
				CFSocketContext context = {0, self, NULL, NULL, NULL};
				CFSocketCallBackType callbacks = kCFSocketReadCallBack | kCFSocketWriteCallBack;
				mSocket = CFSocketCreateWithNative (NULL, bsdSocket, callbacks, &SocketReady, &context);
				CFOptionFlags flags = ~kCFSocketAutomaticallyReenableReadCallBack &
				~kCFSocketAutomaticallyReenableWriteCallBack &
				~kCFSocketCloseOnInvalidate &
				CFSocketGetSocketFlags (mSocket);
				CFSocketSetSocketFlags (mSocket, flags);
				mSocketSource = CFSocketCreateRunLoopSource (NULL, mSocket, 0);
				
				BXAssertLog (mSocket, @"Expected source to have been created.");
				BXAssertLog (CFSocketIsValid (mSocket), @"Expected socket to be valid.");
				BXAssertLog (mSocketSource, @"Expected socketSource to have been created.");
				BXAssertLog (CFRunLoopSourceIsValid (mSocketSource), @"Expected socketSource to be valid.");
				
				CFRunLoopRef runloop = mRunLoop ?: CFRunLoopGetCurrent ();
				CFStringRef mode = kCFRunLoopCommonModes;
				CFSocketDisableCallBacks (mSocket, kCFSocketReadCallBack);
				CFSocketEnableCallBacks (mSocket, kCFSocketWriteCallBack);
				CFRunLoopAddSource (runloop, mSocketSource, mode);
				
				retval = YES;
			}
			else
			{
				[self finishedConnecting: NO];
			}
		}
	}
	return retval;
}

@end


@implementation PGTSSynchronousConnector
- (BOOL) connect: (const char *) conninfo
{
    BOOL retval = NO;
	mNegotiationStarted = NO;
	if ([self start: conninfo] && CONNECTION_BAD != PQstatus (mConnection))
	{
		mNegotiationStarted = YES;
		fd_set mask = {};
		struct timeval timeout = {.tv_sec = 15, .tv_usec = 0};
		PostgresPollingStatusType pollingStatus = PGRES_POLLING_WRITING; //Start with this
		int selectStatus = 0;
		int bsdSocket = PQsocket (mConnection);
		BOOL stop = NO;
		
		if (mTraceFile)
			PQtrace (mConnection, mTraceFile);
		
		if (bsdSocket < 0)
			BXLogInfo (@"Unable to get connection socket from libpq.");
		else
		{
			//Polling loop
			while (1)
			{
				struct timeval ltimeout = timeout;
				FD_ZERO (&mask);
				FD_SET (bsdSocket, &mask);
				selectStatus = 0;
				pollingStatus = mPollFunction (mConnection);
				
				BXLogDebug (@"Polling status: %d connection status: %d", pollingStatus, PQstatus (mConnection));
#ifdef USE_SSL
				if (NO == mSSLSetUp && CONNECTION_SSL_CONTINUE == PQstatus (mConnection))
				{
					mSSLSetUp = YES;
					SSL* ssl = PQgetssl (mConnection);
					BXAssertValueReturn (NULL != ssl, NO, @"Expected ssl struct not to be NULL.");
					SSL_set_verify (ssl, SSL_VERIFY_PEER, &VerifySSLCertificate);
					SSL_set_ex_data (ssl, SSLConnectionExIndex (), self);
				}
#endif
				
				switch (pollingStatus)
				{
					case PGRES_POLLING_OK:
						retval = YES;
						//Fall through.
					case PGRES_POLLING_FAILED:
						stop = YES;
						break;
						
					case PGRES_POLLING_ACTIVE:
						//Select returns 0 on timeout
						selectStatus = 1;
						break;
						
					case PGRES_POLLING_READING:
						selectStatus = select (bsdSocket + 1, &mask, NULL, NULL, &ltimeout);
						break;
						
					case PGRES_POLLING_WRITING:
					default:
						selectStatus = select (bsdSocket + 1, NULL, &mask, NULL, &ltimeout);
						break;
				} //switch
				
				if (0 == selectStatus)
				{
					//Timeout.
					break;
				}
				else if (selectStatus < 0 || YES == stop)
				{
					break;
				}
			}			
		}		
	}
	
	[self finishedConnecting: retval && CONNECTION_OK == PQstatus (mConnection)];
	return retval;
}
@end


@implementation PGTSSynchronousReconnector
- (id) init
{
    if ((self = [super init]))
    {
        mPollFunction = &PQresetPoll;
    }
    return self;
}

- (BOOL) start: (const char *) connectionString
{
	return (BOOL) PQresetStart (mConnection);
}
@end


@implementation PGTSAsynchronousReconnector
- (id) init
{
    if ((self = [super init]))
    {
        mPollFunction = &PQresetPoll;
    }
    return self;
}

- (BOOL) start: (const char *) connectionString
{
	return (BOOL) PQresetStart (mConnection);
}
@end
