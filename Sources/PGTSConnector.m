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
#ifdef USE_SSL
#import <openssl/ssl.h>
#endif

//FIXME: enable these.
#undef USE_SSL
#define log4AssertValueReturn(...) 
#define log4AssertLog(...)


@implementation PGTSConnector

static void 
SocketReady (CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void* data, void* self)
{
	[(id) self socketReady];
}

- (id) init
{
    if ((self = [super init]))
    {
        mPollFunction = &PQconnectPoll;
    }
    return self;
}

- (void) setDelegate: (id <PGTSConnectorDelegate>) anObject
{
	mDelegate = anObject;
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
	[super dealloc];
}

- (void) finalize
{
	[self freeCFTypes];
	[super finalize];
}

- (void) socketReady
{
	PostgresPollingStatusType status = mPollFunction (mConnection);
	
#ifdef USE_SSL
	if (! mSSLSetUp && CONNECTION_SSL_CONTINUE == PQstatus (mConnection))
	{
		mSSLSetUp = YES;
		SSL* ssl = PQgetssl (connection);
		log4AssertValueReturn (ssl, NO, @"Expected ssl struct not to be NULL.");
		SSL_set_verify (ssl, SSL_VERIFY_PEER, &PGTSVerifySSLCertificate);
		SSL_set_ex_data (ssl, PGTSSSLConnectionExIndex (), self);
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
	[mDelegate connector: self gotConnection: mConnection succeeded: succeeded];
}

- (BOOL) connect: (const char *) conninfo
{
	BOOL retval = NO;	
	if ((mConnection = PQconnectStart (conninfo)) && CONNECTION_BAD != PQstatus (mConnection))
	{
		int bsdSocket = PQsocket (mConnection);
		if (0 <= bsdSocket)
		{			
			CFSocketContext context = {0, self, NULL, NULL, NULL};
			CFSocketCallBackType callbacks = kCFSocketReadCallBack | kCFSocketWriteCallBack;
			mSocket = CFSocketCreateWithNative (NULL, bsdSocket, callbacks, &SocketReady, &context);
			CFOptionFlags flags = ~kCFSocketAutomaticallyReenableReadCallBack &
								  ~kCFSocketAutomaticallyReenableWriteCallBack &
								  ~kCFSocketCloseOnInvalidate &
								  CFSocketGetSocketFlags (mSocket);
			CFSocketSetSocketFlags (mSocket, flags);
			mSocketSource = CFSocketCreateRunLoopSource (NULL, mSocket, 0);
			
			log4AssertLog (mSocket, @"Expected source to have been created.");
			log4AssertLog (CFSocketIsValid (mSocket), @"Expected socket to be valid.");
			log4AssertLog (mSocketSource, @"Expected socketSource to have been created.");
			log4AssertLog (CFRunLoopSourceIsValid (mSocketSource), @"Expected socketSource to be valid.");
			
			CFRunLoopRef runloop = mRunLoop ?: CFRunLoopGetCurrent ();
			CFStringRef mode = kCFRunLoopCommonModes;
			CFSocketDisableCallBacks (mSocket, kCFSocketReadCallBack);
			CFSocketEnableCallBacks (mSocket, kCFSocketWriteCallBack);
			CFRunLoopAddSource (runloop, mSocketSource, mode);
            
            retval = YES;
		}
	}
	return retval;
}

@end