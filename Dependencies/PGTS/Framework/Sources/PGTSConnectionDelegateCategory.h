//
// PGTSConnectionDelegate.h
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
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

/** See PGTSConstants.h */
/** See PGTSFunctions.m */

extern SEL kPGTSResultSetSelector;
extern SEL kPGTSQueryFailedSelector;
extern SEL kPGTSQueryDispatchSucceededSelector;
extern SEL kPGTSQueryDispatchFailedSelector;
extern SEL kPGTSConnectionReceivedNoticeSelector;

extern SEL kPGTSConnectionFailedSelector;
extern SEL kPGTSConnectionSucceededSelector;
extern SEL kPGTSStartedReconnectingSelector;
extern SEL kPGTSReconnectionFailedSelector;
extern SEL kPGTSReconnectionSucceededSelector;


@interface NSObject (PGTSConnectionDelegate)
- (void) PGTSConnection: (PGTSConnection *) connection sentQuery: (NSString *) queryString;
- (void) PGTSConnection: (PGTSConnection *) connection failedToSendQuery: (NSString *) queryString;
- (BOOL) PGTSConnection: (PGTSConnection *) connection acceptCopyingData: (NSData *) data errorMessage: (NSString **) errorMessage;
- (void) PGTSConnection: (PGTSConnection *) connection receivedData: (NSData *) data;
- (void) PGTSConnection: (PGTSConnection *) connection receivedResultSet: (PGTSResultSet *) result;
- (void) PGTSConnection: (PGTSConnection *) connection receivedError: (PGTSResultSet *) result;
- (void) PGTSConnection: (PGTSConnection *) connection receivedNotice: (NSNotification *) notice;
- (void) PGTSConnectionFailed: (PGTSConnection *) connection;
- (void) PGTSConnectionEstablished: (PGTSConnection *) connection;
- (void) PGTSConnectionStartedReconnecting: (PGTSConnection *) connection;
- (void) PGTSConnectionFailedToReconnect: (PGTSConnection *) connection;
- (void) PGTSConnectionDidReconnect: (PGTSConnection *) connection;
@end


@protocol PGTSConnectionDelegate <NSObject>
@end