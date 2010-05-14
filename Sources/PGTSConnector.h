//
// PGTSConnector.h
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

#import <Foundation/Foundation.h>
#import <BaseTen/BXExport.h>
#import <BaseTen/libpq-fe.h>

@class PGTSConnector;


BX_INTERNAL char *PGTSCopyConnectionString (NSDictionary *);


@protocol PGTSConnectorDelegate <NSObject>
- (void) connector: (PGTSConnector *) connector gotConnection: (PGconn *) connection;
- (void) connectorFailed: (PGTSConnector *) connector;
- (BOOL) allowSSLForConnector: (PGTSConnector *) connector context: (void *) x509_ctx preverifyStatus: (int) preverifyStatus;
@end


@interface PGTSConnector : NSObject
{
	id <PGTSConnectorDelegate> mDelegate; //Weak
	PostgresPollingStatusType (* mPollFunction)(PGconn *);
	PGconn* mConnection;
	NSError* mConnectionError;
	FILE* mTraceFile;
	BOOL mSSLSetUp;
	BOOL mNegotiationStarted;
	BOOL mServerCertificateVerificationFailed;
}
- (BOOL) connect: (NSDictionary *) connectionDictionary;
- (void) cancel;
- (id <PGTSConnectorDelegate>) delegate;
- (void) setDelegate: (id <PGTSConnectorDelegate>) anObject;
- (void) setConnection: (PGconn *) connection;
- (void) setServerCertificateVerificationFailed: (BOOL) aBool;

- (BOOL) start: (const char *) connectionString;
- (void) setTraceFile: (FILE *) stream;

- (NSError *) connectionError;
- (void) setConnectionError: (NSError *) anError;

- (void) finishedConnecting: (BOOL) status;
- (void) setUpSSL;
- (void) prepareForConnect;
@end
