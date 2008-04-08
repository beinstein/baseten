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


@implementation PGTSConnector

static void 
SocketReady (CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void* data, void* self)
{
	[(id) self socketReady];
}

- (void) dealloc
{
}

- (void) socketReady
{
	PostgresPollingStatusType status = PQconnectPoll (mConnection);
	
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
			CFSocketEnableCallbackTypes (kCFSocketReadCallBack);
            break;
            
        case PGRES_POLLING_WRITING:
        default:
			CFSocketEnableCallbackTypes (kCFSocketWriteCallBack);
            break;
	}
}

- (void) finishedConnecting: (BOOL) succeeded
{
	//FIXME: call the delegate
}

- (BOOL) connectAsync: (NSString *) connectionString
{
	BOOL retval = NO;	
	const char* conninfo = [connectionString UTF8String];
	if ((mConnection = PQconnectStart (conninfo)) && CONNECTION_BAD != PQstatus (mConnection))
	{
		int bsdSocket = PQsocket (mConnection);
		if (0 <= bsdSocket)
		{			
			CFSocketContext context = {0, self, NULL, NULL, NULL};
			mSocket = CFSocketCreateWithNative (NULL, bsdSocket, kCFSocketReadCallBack | kCFSocketWriteCallBack, &SocketReady, &context);
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
			
			CFRunLoopRef runloop = CFRunLoopGetCurrent ();
			CFStringRef mode = kCFRunLoopCommonModes;
			CFRunLoopAddSource (runloop, mSocketSource, mode);
			CFSocketEnableCallbackTypes (kCFSocketWriteCallBack);
		}
	}
	return retval;
}

@end