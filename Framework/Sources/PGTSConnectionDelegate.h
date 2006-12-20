//
// PGTSConnectionDelegate.h
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

#import <PGTS/PGTSConstants.h>
#import <PGTS/postgresql/libpq-fe.h>

/** See PGTSConstants.h */
/** See PGTSConstants.m */
/** See PGTSFunctions.m */

/** Selectors for delegate methods */
//@{
PGTS_EXPORT SEL kPGTSSentQuerySelector;
PGTS_EXPORT SEL kPGTSFailedToSendQuerySelector;
PGTS_EXPORT SEL kPGTSAcceptCopyingDataSelector;
PGTS_EXPORT SEL kPGTSReceivedDataSelector;
PGTS_EXPORT SEL kPGTSReceivedResultSetSelector;
PGTS_EXPORT SEL kPGTSReceivedErrorSelector;
PGTS_EXPORT SEL kPGTSReceivedNoticeSelector;

PGTS_EXPORT SEL kPGTSConnectionFailedSelector;
PGTS_EXPORT SEL kPGTSConnectionEstablishedSelector;
PGTS_EXPORT SEL kPGTSStartedReconnectingSelector;
PGTS_EXPORT SEL kPGTSDidReconnectSelector;
//@}


@class PGTSConnection;
@class PGTSResultSet;

/** Informal part of the protocol */
@interface NSObject (PGTSConnectionDelegate)
/** Callbacks for asynchronous query methods */
//@{
- (void) PGTSConnection: (PGTSConnection *) connection sentQuery: (NSString *) queryString;
- (void) PGTSConnection: (PGTSConnection *) connection failedToSendQuery: (NSString *) queryString;
- (void) PGTSConnection: (PGTSConnection *) connection receivedResultSet: (PGTSResultSet *) result;
- (void) PGTSConnection: (PGTSConnection *) connection receivedError: (PGTSResultSet *) result;
- (void) PGTSConnection: (PGTSConnection *) connection receivedNotice: (NSNotification *) notice;
//@}
/** Callback for sendCopyData: and sendCopyData:pakcetSize: */
- (BOOL) PGTSConnection: (PGTSConnection *) connection acceptCopyingData: (NSData *) data errorMessage: (NSString **) errorMessage;
/** Callback for receiveCopyData */
- (void) PGTSConnection: (PGTSConnection *) connection receivedData: (NSData *) data;

/** Callbacks for asynchronous connecting and reconnecting */
//@{
- (void) PGTSConnectionFailed: (PGTSConnection *) connection;
- (void) PGTSConnectionEstablished: (PGTSConnection *) connection;
- (void) PGTSConnectionStartedReconnecting: (PGTSConnection *) connection;
- (void) PGTSConnectionDidReconnect: (PGTSConnection *) connection;
//@}
@end


/** Formal part of the protocol */
@protocol PGTSConnectionDelegate <NSObject>
@end


@interface NSObject (PGTSNotifierDelegate)
- (BOOL) PGTSNotifierShouldHandleNotification: (NSNotification *) notification fromTableWithOid: (Oid) oid;
@end