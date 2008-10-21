//
// PGTSQueryDescription.m
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

#import "PGTSQueryDescription.h"
#import "PGTSConnection.h"
#import "PGTSResultSet.h"
#import "PGTSQuery.h"
#import "PGTSConnectionPrivate.h"
#import "PGTSProbes.h"
#import <BaseTen/postgresql/libpq-fe.h>


static int gIdentifier = 0;
static int
NextIdentifier ()
{
	gIdentifier++;
	return gIdentifier;
}

@implementation PGTSQueryDescription

- (SEL) callback
{
	return NULL;
}

- (void) setCallback: (SEL) aSel
{
}

- (id) delegate
{
	return nil;
}

- (void) setDelegate: (id) anObject
{
}

- (int) identifier
{
	return 0;
}

- (PGTSQuery *) query
{
	return nil;
}

- (void) setQuery: (PGTSQuery *) aQuery
{
}

- (BOOL) sent
{
	return NO;
}

- (BOOL) finished
{
	return YES;
}

- (int) sendForConnection: (PGTSConnection *) connection
{
    return -1;
}

- (PGTSResultSet *) receiveForConnection: (PGTSConnection *) connection
{
    return nil;
}

- (PGTSResultSet *) finishForConnection: (PGTSConnection *) connection
{
    return nil;
}

- (void) setUserInfo: (id) userInfo
{
}
@end


@implementation PGTSConcreteQueryDescription
- (void) dealloc
{
	[mQuery release];
	[mUserInfo release];
	[super dealloc];
}

- (id) init
{
	if ((self = [super init]))
	{
		@synchronized ([PGTSQueryDescription class])
		{
			mIdentifier = NextIdentifier ();
		}
	}
	return self;
}

- (SEL) callback
{
	return mCallback;
}

- (void) setCallback: (SEL) aSel
{
	mCallback = aSel;
}

- (id) delegate
{
	return mDelegate;
}

- (void) setDelegate: (id) anObject
{
	mDelegate = anObject;
}

- (int) identifier
{
	return mIdentifier;
}

- (PGTSQuery *) query
{
	return mQuery;
}

- (void) setQuery: (PGTSQuery *) aQuery
{
	if (mQuery != aQuery)
	{
		[mQuery release];
		mQuery = [aQuery retain];
	}
}

- (BOOL) sent
{
	return mSent;
}

- (BOOL) finished
{
	return mFinished;
}

- (int) sendForConnection: (PGTSConnection *) connection
{
    int retval = [mQuery sendQuery: connection];
	//FIXME: check retval?
	mSent = YES;
	return retval;
}

- (PGTSResultSet *) receiveForConnection: (PGTSConnection *) connection
{	
    PGTSResultSet* retval = nil;
    PGconn* pgConn = [connection pgConnection];
    PGresult* result = PQgetResult (pgConn);
	
    if (result)
    {
        retval = [PGTSResultSet resultWithPGresult: result connection: connection];
        [retval setIdentifier: mIdentifier];
		[retval setUserInfo: mUserInfo];
        [mDelegate performSelector: mCallback withObject: retval];
    }
    else
    {
        mFinished = YES;
		
		if (PGTS_FINISH_QUERY_ENABLED ())
			PGTS_FINISH_QUERY ();
    }
    return retval;
}

- (PGTSResultSet *) finishForConnection: (PGTSConnection *) connection
{
    id retval = nil;
    if (! mSent)
        [self sendForConnection: connection];
    
    while (! mFinished)
    {
        retval = [self receiveForConnection: connection] ?: retval;
        [connection processNotifications];
    }
    return retval;
}

- (void) setUserInfo: (id) userInfo
{
	if (mUserInfo != userInfo)
	{
		[mUserInfo release];
		mUserInfo = [userInfo retain];
	}
}
@end
