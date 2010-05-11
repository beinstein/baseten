//
// PGTSSynchronousConnector.m
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

#import "PGTSSynchronousConnector.h"
#import "BXLogger.h"


@implementation PGTSSynchronousConnector
- (BOOL) connect: (NSDictionary *) connectionDictionary
{
	//Here libpq can resolve the name for us, because we don't use CFRunLoop and CFSocket.

    BOOL retval = NO;
	[self prepareForConnect];
	char* conninfo = PGTSCopyConnectionString (connectionDictionary);
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
