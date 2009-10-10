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
#import "BXConstants.h"
#import "PGTSCertificateVerificationDelegateProtocol.h"
#import "BXLogger.h"
#import "BXError.h"
#import "BXEnumerate.h"
#import "BXArraySize.h"
#import "NSString+PGTSAdditions.h"
#import "libpq_additions.h"
#import <sys/select.h>
#import <arpa/inet.h>
#import <netdb.h>


static char*
CopyConnectionString (NSDictionary* connectionDict)
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



@implementation PGTSAsynchronousConnector

static void
ScheduleHost (CFHostRef theHost, CFRunLoopRef theRunLoop)
{
	if (theHost && theRunLoop)
		CFHostUnscheduleFromRunLoop (theHost, theRunLoop, (CFStringRef) kBXRunLoopCommonMode);
}


static void
UnscheduleHost (CFHostRef theHost, CFRunLoopRef theRunLoop)
{
	if (theHost && theRunLoop)
		CFHostScheduleWithRunLoop (theHost, theRunLoop, (CFStringRef) kBXRunLoopCommonMode);
}


static void 
HostReady (CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError *error, void *self)
{
	BXLogDebug (@"CFHost got ready.");
	UnscheduleHost (theHost, [(id) self CFRunLoop]);
	[(id) self continueFromNameResolution: error];
}


static void 
SocketReady (CFSocketRef s, CFSocketCallBackType callBackType, CFDataRef address, const void* data, void* self)
{
	[(id) self socketReady: callBackType];
}


- (id) init
{
	if ((self = [super init]))
	{
		mExpectedCallBack = 0;
		[self setCFRunLoop: CFRunLoopGetCurrent ()];
	}
	return self;
}


- (CFRunLoopRef) CFRunLoop
{
	return mRunLoop;
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
			CFRunLoopAddCommonMode (mRunLoop, (CFStringRef) kBXRunLoopCommonMode);
		}
	}
}


- (void) setConnectionDictionary: (NSDictionary *) aDict
{
	if (mConnectionDictionary != aDict)
	{
		[mConnectionDictionary release];
		mConnectionDictionary = [aDict retain];
	}
}


- (void) removeHost
{
	if (mHost)
	{
		CFHostCancelInfoResolution (mHost, kCFHostReachability);
		UnscheduleHost (mHost, mRunLoop);
		CFRelease (mHost);
		mHost = NULL;
	}		
}


- (void) freeCFTypes
{
	//Don't release the connection. Delegate will handle it.
	
	[self removeHost];
	
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
	[self removeHost];
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

- (void) prepareForConnect
{
	[super prepareForConnect];
	bzero (&mHostError, sizeof (mHostError));
}


#pragma mark Callbacks

- (void) continueFromNameResolution: (const CFStreamError *) streamError
{
	//If the resolution succeeded, iterate addresses and try to connect to each. Stop when a server gets reached.
	
	BOOL reachedServer = NO;
	BXLogDebug (@"Continuing from name resolution.");
	
	if (streamError && streamError->domain)
	{
		NSString* errorTitle = NSLocalizedStringWithDefaultValue (@"connectionError", nil, [NSBundle bundleForClass: [self class]],
																  @"Connection error", @"Title for a sheet.");
		
		//FIXME: localization.
		NSString* messageFormat = nil;
		const char* reason = NULL;
		if (streamError->domain == kCFStreamErrorDomainNetDB)
		{
			reason = (gai_strerror (streamError->error));
			if (reason)
				messageFormat = @"The server %@ wasn't found: %s.";
			else
				messageFormat = @"The server %@ wasn't found.";
		}
		else if (streamError->domain == kCFStreamErrorDomainSystemConfiguration)
		{
			messageFormat = @"The server %@ wasn't found. Network might be unreachable.";
		}
		else
		{
			messageFormat = @"The server %@ wasn't found.";
		}
		NSString* message = [NSString stringWithFormat: messageFormat, [mConnectionDictionary objectForKey: kPGTSHostKey], reason];
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  errorTitle, NSLocalizedDescriptionKey,
								  errorTitle, NSLocalizedFailureReasonErrorKey,
								  message, NSLocalizedRecoverySuggestionErrorKey,
								  nil];
		//FIXME: error code
		NSError* error = [BXError errorWithDomain: kPGTSConnectionErrorDomain code: kPGTSConnectionErrorUnknown userInfo: userInfo];
		[self setConnectionError: error];		
	}
	else
	{		
		NSArray* addresses = (id) CFHostGetAddressing (mHost, NULL);
		if (addresses)
		{
			char addressBuffer [40] = {}; // 8 x 4 (hex digits in IPv6 address) + 7 (colons) + 1 (nul character)
			
			NSMutableDictionary* connectionDictionary = [[mConnectionDictionary mutableCopy] autorelease];
			[connectionDictionary removeObjectForKey: kPGTSHostKey];
			
			//This is safe because each address is owned by the addresses CFArray which is owned 
			//by mHost which is CFRetained.
			BXEnumerate (addressData, e, [addresses objectEnumerator])
			{
				const struct sockaddr* address = [addressData bytes];
				sa_family_t family = address->sa_family;
				void* addressBytes = NULL;
				
				switch (family)
				{
					case AF_INET:
						addressBytes = &((struct sockaddr_in *) address)->sin_addr.s_addr;
						break;
						
					case AF_INET6:
						addressBytes = ((struct sockaddr_in6 *) address)->sin6_addr.s6_addr;
						break;
						
					default:
						break;
				}
				
				if (addressBytes && inet_ntop (family, addressBytes, addressBuffer, BXArraySize (addressBuffer)))
				{
					NSString* humanReadableAddress = [NSString stringWithUTF8String: addressBuffer];
					BXLogInfo (@"Trying '%@'", humanReadableAddress);
					[connectionDictionary setObject: humanReadableAddress forKey: kPGTSHostAddressKey];
					char* conninfo = CopyConnectionString (connectionDictionary);
					
					if ([self startNegotiation: conninfo])
					{
						reachedServer = YES;
						free (conninfo);
						break;
					}
					
					free (conninfo);
				}
			}
		}
	}
	
	if (reachedServer)
		[self negotiateConnection];
	else
		[self finishedConnecting: NO];
}


- (void) socketReady: (CFSocketCallBackType) callBackType
{
	BXLogDebug (@"Socket got ready.");
	
	//Sometimes the wrong callback type gets called. We cope with this
	//by checking against an expected type and re-enabling it if needed.
	if (callBackType != mExpectedCallBack)
		CFSocketEnableCallBacks (mSocket, mExpectedCallBack);
	else
	{
		PostgresPollingStatusType status = mPollFunction (mConnection);
		
		[self setUpSSL];
		
		switch (status)
		{
			case PGRES_POLLING_OK:
				[self finishedConnecting: YES];
				break;
				
			case PGRES_POLLING_FAILED:
				[self finishedConnecting: NO];
				break;
				
			case PGRES_POLLING_ACTIVE:
				[self socketReady: mExpectedCallBack];
				break;
				
			case PGRES_POLLING_READING:
				CFSocketEnableCallBacks (mSocket, kCFSocketReadCallBack);
				mExpectedCallBack = kCFSocketReadCallBack;
				break;
				
			case PGRES_POLLING_WRITING:
			default:
				CFSocketEnableCallBacks (mSocket, kCFSocketWriteCallBack);
				mExpectedCallBack = kCFSocketWriteCallBack;
				break;
		}
	}
}


- (void) finishedConnecting: (BOOL) succeeded
{
	[self freeCFTypes];
	[super finishedConnecting: succeeded];
}


#pragma mark Connection methods

- (BOOL) connect: (NSDictionary *) connectionDictionary
{
	BXLogDebug (@"Beginning connecting.");
	
	BOOL retval = NO;
	mExpectedCallBack = 0;
	[self prepareForConnect];
	[self setConnectionDictionary: connectionDictionary];
	
	//CFSocket etc. do some nice things for us that prevent libpq from noticing
	//connection problems. This causes SIGPIPE to be sent to us, and we get
	//"Broken pipe" as the error message. To cope with this, we check the socket's
	//status after connecting but before giving it to CFSocket.
	//For this to work, we need to resolve the host name by ourselves, if we have one.
    //If the name begins with a slash, it is a path to socket.
	
	NSString* name = [connectionDictionary objectForKey: kPGTSHostKey];
	if (0 < [name length] && '/' != [name characterAtIndex: 0])
	{
		Boolean status = FALSE;
		CFHostClientContext ctx = {
			0,
			self,
			NULL,
			NULL,
			NULL
		};
				
		[self removeHost];
		mHost = CFHostCreateWithName (NULL, (CFStringRef) name);
		status = CFHostSetClient (mHost, &HostReady, &ctx);
		BXLogDebug (@"Set host client: %d.", status);
		ScheduleHost (mHost, mRunLoop);
		
		status = CFHostStartInfoResolution (mHost, kCFHostAddresses, &mHostError);
		BXLogDebug (@"Started host info resolution: %d.", status);
		if (! status)
		{
			UnscheduleHost (mHost, mRunLoop);
			[self continueFromNameResolution: &mHostError];
		}
	}
	else
	{
		char* conninfo = CopyConnectionString (mConnectionDictionary);
		if ([self startNegotiation: conninfo])
		{
			retval = YES;
			[self negotiateConnection];
		}
		else
		{
			[self finishedConnecting: NO];
		}
		free (conninfo);
	}
	
	return retval;
}


- (BOOL) startNegotiation: (const char *) conninfo
{
	BXLogDebug (@"Beginning negotiation.");
	
	mNegotiationStarted = NO;
	BOOL retval = NO;
	if ([self start: conninfo])
	{
		if (CONNECTION_BAD != PQstatus (mConnection))
		{
			mNegotiationStarted = YES;
			int socket = PQsocket (mConnection);
			if (socket < 0)
				BXLogInfo (@"Unable to get connection socket from libpq.");
			else
			{
				//We mimic libpq's error message because it doesn't provide us with error codes.
				//Also we need to select first to make sure that getsockopt returns an accurate error message.
				
				BOOL haveError = NO;
				NSString* reason = nil;
				
				{
					char message [256] = {};
					int status = 0;
					
					struct timeval timeout = {.tv_sec = 15, .tv_usec = 0};
					fd_set mask = {};
					FD_ZERO (&mask);
					FD_SET (socket, &mask);
					status = select (socket + 1, NULL, &mask, NULL, &timeout);		
					
					if (status <= 0)
					{
						haveError = YES;
						strerror_r (errno, message, BXArraySize (message));
						reason = [NSString stringWithUTF8String: message];
					}
					else
					{
						int optval = 0;
						socklen_t size = sizeof (optval);
						status = getsockopt (socket, SOL_SOCKET, SO_ERROR, &optval, &size);
						
						if (0 == status)
						{
							if (0 == optval)
								retval = YES;
							else
							{			
								haveError = YES;
								strerror_r (optval, message, BXArraySize (message));
								reason = [NSString stringWithUTF8String: message];
							}
						}
						else
						{
							haveError = YES;
						}
					}
				}
				
				if (haveError)
				{
					NSString* errorTitle = NSLocalizedStringWithDefaultValue (@"connectionError", nil, [NSBundle bundleForClass: [self class]],
																			  @"Connection error", @"Title for a sheet.");
					NSString* messageFormat = NSLocalizedStringWithDefaultValue (@"libpqStyleConnectionErrorFormat", nil, [NSBundle bundleForClass: [self class]],
																				 @"Could not connect to server: %@. Is the server running at \"%@\" and accepting TCP/IP connections on port %s?", 
																				 @"Reason for error");		
					if (! reason)
					{
						reason = NSLocalizedStringWithDefaultValue (@"connectionRefused", nil, [NSBundle bundleForClass: [self class]],
																	@"Connection refused", @"Reason for error");
					}
					
					NSString* address = ([mConnectionDictionary objectForKey: kPGTSHostKey] ?: [mConnectionDictionary objectForKey: kPGTSHostAddressKey]);
					NSString* message = [NSString stringWithFormat: messageFormat, reason, address, PQport (mConnection)];
					NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  errorTitle, NSLocalizedDescriptionKey,
											  errorTitle, NSLocalizedFailureReasonErrorKey,
											  message, NSLocalizedRecoverySuggestionErrorKey,
											  nil];		
					NSError* error = [BXError errorWithDomain: kPGTSConnectionErrorDomain code: kPGTSConnectionErrorUnknown userInfo: userInfo];
					[self setConnectionError: error];
				}				
			}
		}
	}
	
	return retval;
}


- (void) negotiateConnection
{
	BXLogDebug (@"Negotiating.");
	
	if (mTraceFile)
		PQtrace (mConnection, mTraceFile);
	
	CFSocketContext context = {0, self, NULL, NULL, NULL};
	CFSocketCallBackType callbacks = kCFSocketReadCallBack | kCFSocketWriteCallBack;
	mSocket = CFSocketCreateWithNative (NULL, PQsocket (mConnection), callbacks, &SocketReady, &context);
	CFOptionFlags flags = 
	~kCFSocketAutomaticallyReenableReadCallBack &
	~kCFSocketAutomaticallyReenableWriteCallBack &
	~kCFSocketCloseOnInvalidate &
	CFSocketGetSocketFlags (mSocket);
	
	CFSocketSetSocketFlags (mSocket, flags);
	mSocketSource = CFSocketCreateRunLoopSource (NULL, mSocket, 0);
	
	BXAssertLog (mSocket, @"Expected source to have been created.");
	BXAssertLog (CFSocketIsValid (mSocket), @"Expected socket to be valid.");
	BXAssertLog (mSocketSource, @"Expected socketSource to have been created.");
	BXAssertLog (CFRunLoopSourceIsValid (mSocketSource), @"Expected socketSource to be valid.");
	
	CFSocketDisableCallBacks (mSocket, kCFSocketReadCallBack);
	CFSocketEnableCallBacks (mSocket, kCFSocketWriteCallBack);
	mExpectedCallBack = kCFSocketWriteCallBack;
	CFRunLoopAddSource (mRunLoop, mSocketSource, (CFStringRef) kBXRunLoopCommonMode);
}
@end


@implementation PGTSSynchronousConnector
- (BOOL) connect: (NSDictionary *) connectionDictionary
{
	//Here libpq can resolve the name for us, because we don't use CFRunLoop and CFSocket.

    BOOL retval = NO;
	[self prepareForConnect];
	char* conninfo = CopyConnectionString (connectionDictionary);
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
				
				[self setUpSSL];
				
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
	
	if (conninfo)
		free (conninfo);
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
